import AppKit

// Only included in the isolated acceptance executable. Records event times and
// counts from its test suite, never tasks, notes, formal preferences or secrets.
@MainActor final class AcceptanceLifecycleRecorder {
    private let defaults: UserDefaults
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var timer: Timer?
    private let destination = URL(fileURLWithPath: "/private/tmp/pang-acceptance-lifecycle.jsonl")

    init(defaults: UserDefaults) {
        self.defaults = defaults
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            let center = NSWorkspace.shared.notificationCenter
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] event in
                Task { @MainActor [weak self] in self?.record(event.name.rawValue) }
            }
            observers.append((center, token))
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            let token = DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil,
                queue: .main) { [weak self] event in
                Task { @MainActor [weak self] in self?.record(event.name.rawValue) }
            }
            distributedObservers.append(token)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.record("checkpoint") }
        }
        record("recorderStarted")
    }

    func record(_ event: String) {
        let snapshot = defaults.data(forKey: "pangpang.pomodoro.snapshot")
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        var row: [String: Any] = ["event": event, "unixTime": Date().timeIntervalSince1970,
            "uptime": ProcessInfo.processInfo.systemUptime,
            "records": (snapshot["records"] as? [Any])?.count ?? 0,
            "completedFocuses": snapshot["completedFocuses"] as? Int ?? 0,
            "phase": snapshot["phase"] as? String ?? "notStarted"]
        for key in ["endDate", "activeSessionID"] { if let value = snapshot[key] { row[key] = value } }
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        data.append(10)
        if !FileManager.default.fileExists(atPath: destination.path) {
            FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        if let file = try? FileHandle(forWritingTo: destination) {
            defer { try? file.close() }
            _ = try? file.seekToEnd(); try? file.write(contentsOf: data)
        }
    }
}
