import Combine
import Foundation
import HealthKit
import UserNotifications

/// 负责读取 Apple Health 中已存在的 HRV 数据，并转换为 UI 所需的状态。
/// HRV 并非由本 App 持续采样；Apple Watch 写入新样本后，系统才可能唤醒查询。
final class HRVManager: NSObject, ObservableObject {

    static let shared = HRVManager()

    // MARK: - UI State

    @Published private(set) var latestHRV: Double?
    @Published private(set) var heartRate: Double?
    @Published private(set) var isLoading = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var hrvReadings: [HRVReading] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var latestTimestamp: Date?
    @Published private(set) var currentStatus: HRVStatus = .unknown
    @Published private(set) var healthAccessStatus = "尚未请求"
    @Published private(set) var notificationStatus = "尚未检查"
    @Published private(set) var backgroundDeliveryStatus = "尚未启用"
    @Published private(set) var lastSuccessfulRefresh: Date?
    @Published private(set) var testNotificationStatus: String?

    static let remindersEnabledKey = "remindersEnabled"
    static let lowHRVThresholdKey = "lowHRVThresholdRatio"
    private static let reminderMutedDayKey = "reminderMutedDay"
    private static let lastLowHRVReminderSampleTimestampKey = "lastLowHRVReminderSampleTimestamp"
    private static let lastLowHRVReminderScheduledAtKey = "lastLowHRVReminderScheduledAt"
    private static let reminderCategoryIdentifier = "BikiniBotomHRV.lowHRV"
    private static let muteTodayActionIdentifier = "BikiniBotomHRV.muteToday"
    private static let baselineWindowDays = 28
    private static let baselineMinimumSamples = 7
    private static let reminderCooldown: TimeInterval = 60 * 60

    /// 模拟器没有真实 Apple Watch HRV 历史，因此仅在模拟器展示演示数据。
    var isDemoMode: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// 以近 28 天的中位数作个人基线；少于 7 个样本时不建立基线，避免误导。
    var baseline28d: Double? {
        let values = hrvReadings.map(\.sdnn).sorted()
        guard values.count >= Self.baselineMinimumSamples else { return nil }

        let middle = values.count / 2
        return values.count.isMultiple(of: 2)
            ? (values[middle - 1] + values[middle]) / 2
            : values[middle]
    }

    /// 基线查询会保留 28 天样本；手表主界面只显示最近 7 天趋势，保持可读性。
    var dailyTrend: [HRVDailyPoint] {
        let calendar = Calendar.current
        let trendStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        let readingsByDay = Dictionary(grouping: hrvReadings.filter { $0.timestamp >= trendStart }) {
            calendar.startOfDay(for: $0.timestamp)
        }

        return readingsByDay.map { date, readings in
            let values = readings.map(\.sdnn).sorted()
            let middle = values.count / 2
            let median = values.count.isMultiple(of: 2)
                ? (values[middle - 1] + values[middle]) / 2
                : values[middle]
            return HRVDailyPoint(date: date, sdnn: median)
        }
        .sorted { $0.date < $1.date }
    }

    var remindersEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.remindersEnabledKey) as? Bool ?? true
    }

    var reminderThresholdPercent: Int {
        Int((lowHRVThresholdRatio * 100).rounded())
    }

    var baselineProgressText: String {
        guard baseline28d == nil else { return "已建立（28 天）" }
        return "还差 \(max(0, Self.baselineMinimumSamples - hrvReadings.count)) 条样本"
    }

    var reminderEvaluationText: String {
        guard remindersEnabled else { return "提醒已关闭" }
        guard !isReminderMutedToday else { return "今天已静音，明天会自动恢复" }
        guard !isInQuietHours else { return "23:00–09:00 为静默时段，不发送提醒" }
        guard !isReminderCoolingDown else { return cooldownText }
        guard let latestHRV, let baseline = baseline28d, baseline > 0 else {
            return "等待至少 7 条 HRV 样本建立 28 天基线"
        }
        return latestHRV < baseline * lowHRVThresholdRatio
            ? "当前读数符合低 HRV 提醒条件"
            : "当前读数未达到提醒阈值"
    }

    var isReminderMutedToday: Bool {
        let mutedDay = UserDefaults.standard.double(forKey: Self.reminderMutedDayKey)
        guard mutedDay > 0 else { return false }
        return Calendar.current.isDate(Date(timeIntervalSince1970: mutedDay), inSameDayAs: Date())
    }

    var reminderMuteText: String {
        isReminderMutedToday ? "今天已静音" : "今天仍会提醒"
    }

    var isInQuietHours: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 23 || hour < 9
    }

    var isReminderCoolingDown: Bool {
        let lastReminder = UserDefaults.standard.double(forKey: Self.lastLowHRVReminderScheduledAtKey)
        guard lastReminder > 0 else { return false }
        return Date().timeIntervalSince1970 - lastReminder < Self.reminderCooldown
    }

    var reminderProtectionText: String {
        "1 小时冷却 · 23:00–09:00 静默"
    }

    private var cooldownText: String {
        let lastReminder = UserDefaults.standard.double(forKey: Self.lastLowHRVReminderScheduledAtKey)
        let remaining = max(0, Self.reminderCooldown - (Date().timeIntervalSince1970 - lastReminder))
        return "提醒冷却中，约 \(Int(ceil(remaining / 60))) 分钟后恢复"
    }

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private var hrvObserverQuery: HKObserverQuery?
    private var hasRequestedAuthorization = false
    private var demoScenarioIndex = 0

    private var lowHRVThresholdRatio: Double {
        let value = UserDefaults.standard.double(forKey: Self.lowHRVThresholdKey)
        return value == 0 ? 0.75 : value
    }

    override init() {
        super.init()
        notificationCenter.delegate = self
        configureNotificationActions()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        #if targetEnvironment(simulator)
        healthAccessStatus = "模拟器演示模式"
        notificationStatus = "模拟器无法完整验证"
        backgroundDeliveryStatus = "模拟器无法验证"
        loadDemoData()
        #else
        guard !hasRequestedAuthorization else {
            refresh()
            refreshNotificationStatus()
            return
        }
        hasRequestedAuthorization = true
        healthAccessStatus = "正在请求"

        let typesToRead: Set<HKObjectType> = [hrvType, heartRateType]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            guard let self else { return }

            DispatchQueue.main.async {
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.healthAccessStatus = "请求失败"
                    self.isLoading = false
                    return
                }

                // HealthKit 不会透露单项「读取」权限是否被授予。
                // 请求成功后直接查询；无返回样本会自然显示为“暂无 HRV 数据”。
                self.healthAccessStatus = success
                    ? "已请求；以实际读取结果为准"
                    : "系统未完成授权请求"
                self.startMonitoring()
                self.requestNotificationAuthorization()
            }
        }
        #endif
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "此设备无法使用 Health 数据"
            return
        }

        isMonitoring = true
        refresh()
        refreshNotificationStatus()
        startHRVObserverIfNeeded()
    }

    /// App 被 HealthKit 在后台唤醒时也建立 observer；未授权时查询只会返回空数据。
    func startBackgroundMonitoring() {
        startMonitoring()
    }

    func stopMonitoring() {
        if let hrvObserverQuery {
            healthStore.stop(hrvObserverQuery)
            self.hrvObserverQuery = nil
        }
        isMonitoring = false
    }

    /// 供页面刷新按钮调用。
    func refresh(completion: (() -> Void)? = nil) {
        #if targetEnvironment(simulator)
        loadDemoData()
        completion?()
        #else
        fetchHRVReadings(completion: completion)
        fetchHeartRate()
        #endif
    }

    /// 供诊断页面手动刷新：重新查询数据，也重新读取系统通知状态。
    func refreshDiagnostics(completion: (() -> Void)? = nil) {
        #if targetEnvironment(simulator)
        loadDemoData()
        completion?()
        #else
        fetchHRVReadings(completion: completion)
        fetchHeartRate()
        #endif
        refreshNotificationStatus()
    }

    /// 仅供模拟器验证三种界面状态；不会进入真实 Apple Watch 的产品逻辑。
    func advanceDemoScenario() {
        guard isDemoMode else { return }
        demoScenarioIndex = (demoScenarioIndex + 1) % demoScenarios.count
        loadDemoData()
    }

    // MARK: - Queries

    private func fetchHRVReadings(
        shouldEvaluateReminder: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -Self.baselineWindowDays, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self else {
                completion?()
                return
            }

            let readings: [HRVReading]
            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    completion?()
                }
                return
            } else {
                readings = (samples as? [HKQuantitySample] ?? []).map { sample in
                    HRVReading(
                        timestamp: sample.startDate,
                        sdnn: sample.quantity.doubleValue(for: .secondUnit(with: .milli)),
                        source: "Apple Health"
                    )
                }
            }

            DispatchQueue.main.async {
                self.hrvReadings = readings
                self.latestHRV = readings.first?.sdnn
                self.latestTimestamp = readings.first?.timestamp
                self.currentStatus = self.status(for: readings.first?.sdnn, baseline: self.baseline28d)
                self.isLoading = false
                self.lastSuccessfulRefresh = Date()

                if shouldEvaluateReminder {
                    self.scheduleLowHRVReminderIfNeeded()
                }
                completion?()
            }
        }

        healthStore.execute(query)
    }

    private func fetchHeartRate() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            guard let self, let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            DispatchQueue.main.async {
                self.heartRate = bpm
            }
        }

        healthStore.execute(query)
    }

    private func startHRVObserverIfNeeded() {
        guard hrvObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                completionHandler()
                return
            }

            // 只在 HealthKit 告诉我们有变化时重新拉取近 28 天数据；
            // 不使用 nil anchor 重放整段健康历史。
            self.fetchHRVReadings(shouldEvaluateReminder: true) {
                completionHandler()
            }
        }

        hrvObserverQuery = query
        healthStore.execute(query)
        enableBackgroundDelivery()
    }

    private func enableBackgroundDelivery() {
        DispatchQueue.main.async {
            self.backgroundDeliveryStatus = "正在启用"
        }
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.backgroundDeliveryStatus = "已启用；等待新 HRV 样本"
                } else {
                    let reason = error?.localizedDescription ?? "系统未说明原因"
                    self.backgroundDeliveryStatus = "未启用：\(reason)"
                    self.errorMessage = "后台提醒未启用：\(reason)"
                }
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            self?.refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            let status: String
            switch settings.authorizationStatus {
            case .authorized:
                status = "已允许"
            case .provisional:
                status = "临时允许"
            case .denied:
                status = "已拒绝"
            case .notDetermined:
                status = "尚未选择"
            case .ephemeral:
                status = "临时会话"
            @unknown default:
                status = "状态未知"
            }

            DispatchQueue.main.async {
                self?.notificationStatus = status
            }
        }
    }

    private func configureNotificationActions() {
        let muteToday = UNNotificationAction(
            identifier: Self.muteTodayActionIdentifier,
            title: "今天不再提醒",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: [muteToday],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([category])
    }

    /// 仅在 HealthKit 告知“有新样本”后判断；同一条样本最多提醒一次，
    /// 并遵守 1 小时冷却和夜间静默。
    private func scheduleLowHRVReminderIfNeeded() {
        guard
            UserDefaults.standard.object(forKey: Self.remindersEnabledKey) as? Bool ?? true,
            !isReminderMutedToday,
            !isInQuietHours,
            !isReminderCoolingDown,
            let latestHRV,
            let baseline = baseline28d,
            let timestamp = latestTimestamp,
            baseline > 0,
            latestHRV < baseline * lowHRVThresholdRatio
        else { return }

        let defaults = UserDefaults.standard
        let key = Self.lastLowHRVReminderSampleTimestampKey
        if defaults.double(forKey: key) >= timestamp.timeIntervalSince1970 {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = currentStatus.reminderTitle
        content.body = currentStatus.reminderBody(latestHRV: latestHRV, baseline: baseline)
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryIdentifier

        let request = UNNotificationRequest(
            identifier: "low-hrv-\(timestamp.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            guard error == nil else { return }
            defaults.set(timestamp.timeIntervalSince1970, forKey: key)
            defaults.set(Date().timeIntervalSince1970, forKey: Self.lastLowHRVReminderScheduledAtKey)
        }
    }

    /// 用于真机 Debug 验证通知权限与展示，不依赖真实 HRV 样本。
    func sendTestNotification() {
        testNotificationStatus = "正在安排测试提醒…"

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async {
                    self.testNotificationStatus = "通知未允许，请先在系统设置中开启"
                }
                return
            }

        let content = UNMutableNotificationContent()
        content.title = "海底测试提醒"
        content.body = "通知正常工作！真实低 HRV 提醒会在有新 HealthKit 样本时触发。"
        content.sound = .default
        content.categoryIdentifier = Self.reminderCategoryIdentifier

        let request = UNNotificationRequest(
            identifier: "BikiniBotomHRV.test-notification",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )

            self.notificationCenter.add(request) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let error {
                        self.testNotificationStatus = "测试提醒未发送：\(error.localizedDescription)"
                    } else {
                        self.testNotificationStatus = "已安排，3 秒后提醒"
                    }
                }
            }
        }
    }

    func setLowHRVThresholdRatio(_ ratio: Double) {
        UserDefaults.standard.set(ratio, forKey: Self.lowHRVThresholdKey)
    }

    func setRemindersEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.remindersEnabledKey)
    }

    func muteRemindersForToday() {
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        UserDefaults.standard.set(today, forKey: Self.reminderMutedDayKey)
    }

    // MARK: - Simulator Demo Data

    private var demoScenarios: [(hrvValues: [Double], heartRate: Double)] {
        [
            // 最新值明显高于基线：恢复良好
            ([66, 55, 53, 52, 51, 50, 49], 58),
            // 最新值轻度低于基线：一般
            ([43, 55, 53, 52, 51, 50, 49], 66),
            // 最新值显著低于基线：压力偏高
            ([33, 55, 53, 52, 51, 50, 49], 76)
        ]
    }

    private func loadDemoData() {
        let scenario = demoScenarios[demoScenarioIndex]
        let now = Date()
        let calendar = Calendar.current
        let readings = scenario.hrvValues.enumerated().map { offset, value in
            HRVReading(
                timestamp: calendar.date(byAdding: .day, value: -offset, to: now) ?? now,
                sdnn: value,
                source: "演示数据"
            )
        }

        hrvReadings = readings
        latestHRV = readings.first?.sdnn
        latestTimestamp = readings.first?.timestamp
        heartRate = scenario.heartRate
        currentStatus = status(for: latestHRV, baseline: baseline28d)
        errorMessage = nil
        isLoading = false
        isMonitoring = true
        lastSuccessfulRefresh = Date()
    }

    // MARK: - Presentation Logic

    private func status(for latestHRV: Double?, baseline: Double?) -> HRVStatus {
        guard let latestHRV, let baseline, baseline > 0 else { return .unknown }

        let ratio = latestHRV / baseline
        if ratio >= 0.95 { return .good }
        if ratio >= 0.75 { return .moderate }
        return .stressed
    }
}

// MARK: - Foreground Notifications

extension HRVManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.muteTodayActionIdentifier {
            muteRemindersForToday()
        }
        completionHandler()
    }
}
