import Foundation
import HealthKit

struct PhoneHRVReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sdnn: Double
}

struct PhoneHRVDailyPoint: Identifiable {
    let date: Date
    let sdnn: Double

    var id: Date { date }
}

@MainActor
final class PhoneHRVStore: ObservableObject {
    @Published private(set) var readings: [PhoneHRVReading] = []
    @Published private(set) var isLoading = false
    @Published private(set) var accessMessage = "尚未读取健康数据"
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let calendar = Calendar.current

    var latest: PhoneHRVReading? {
        readings.max { $0.timestamp < $1.timestamp }
    }

    var baseline28d: Double? {
        let values = readings.map(\.sdnn).sorted()
        guard values.count >= 7 else { return nil }
        let middle = values.count / 2
        return values.count.isMultiple(of: 2)
            ? (values[middle - 1] + values[middle]) / 2
            : values[middle]
    }

    var dailyTrend: [PhoneHRVDailyPoint] {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        let groups = Dictionary(grouping: readings.filter { $0.timestamp >= start }) {
            calendar.startOfDay(for: $0.timestamp)
        }
        return groups.compactMap { date, values in
            let sorted = values.map(\.sdnn).sorted()
            guard !sorted.isEmpty else { return nil }
            let middle = sorted.count / 2
            let median = sorted.count.isMultiple(of: 2)
                ? (sorted[middle - 1] + sorted[middle]) / 2
                : sorted[middle]
            return PhoneHRVDailyPoint(date: date, sdnn: median)
        }
        .sorted { $0.date < $1.date }
    }

    var recoveryLabel: String {
        guard let latest, let baseline = baseline28d, baseline > 0 else { return "等待建立基线" }
        let ratio = latest.sdnn / baseline
        if ratio >= 0.95 { return "恢复不错" }
        if ratio >= 0.75 { return "需要留意" }
        return "建议放慢一点"
    }

    var recoveryDescription: String {
        guard let latest, let baseline = baseline28d, baseline > 0 else {
            return "累计 7 条 HRV 样本后，才能形成更可靠的 28 天个人基线。"
        }
        let percent = Int((latest.sdnn / baseline * 100).rounded())
        return "最新 HRV 是 \(Int(latest.sdnn)) ms，约为个人基线的 \(percent)% 。"
    }

    func requestAuthorizationAndLoad() {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessMessage = "此设备无法使用健康数据"
            return
        }
        isLoading = true
        let types: Set<HKObjectType> = [hrvType]
        healthStore.requestAuthorization(toShare: nil, read: types) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.accessMessage = "请求失败"
                    self.isLoading = false
                    return
                }
                self.accessMessage = success ? "已请求访问权限" : "未完成权限请求"
                self.loadReadings()
            }
        }
    }

    func loadReadings() {
        isLoading = true
        errorMessage = nil
        let start = calendar.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, error in
            let result = (samples as? [HKQuantitySample] ?? []).map {
                PhoneHRVReading(timestamp: $0.startDate, sdnn: $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
            }
            Task { @MainActor in
                guard let self else { return }
                self.readings = result
                self.errorMessage = error?.localizedDescription
                self.accessMessage = error == nil ? "近 28 天读取到 \(result.count) 条 HRV 样本" : "读取失败"
                self.isLoading = false
            }
        }
        healthStore.execute(query)
    }
}
