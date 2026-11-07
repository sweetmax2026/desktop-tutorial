import Foundation

struct AppSupportConfiguration {
    let feedbackURL: URL?
    let appStoreID: String?
    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        let endpoint = (info["PangFeedbackURL"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: endpoint), url.scheme == "https", url.host != nil,
           url.user == nil, url.password == nil, url.query == nil, url.fragment == nil {
            feedbackURL = url
        } else { feedbackURL = nil }
        let candidate = (info["PangAppStoreID"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        appStoreID = !candidate.isEmpty && candidate.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } ? candidate : nil
    }
    var productURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id" + $0) }
    }
}

struct SupportFeedbackDraft: Equatable {
    var id = UUID()
    var category = "使用问题" { didSet { if category != oldValue { id = UUID() } } }
    var content = "" { didSet { if content != oldValue { id = UUID() } } }
    var contact = "" { didSet { if contact != oldValue { id = UUID() } } }
    var includesVersion = true { didSet { if includesVersion != oldValue { id = UUID() } } }
    var isValid: Bool {
        ["使用问题", "功能建议", "其他"].contains(category) &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.unicodeScalars.count <= 2000 && contact.unicodeScalars.count <= 200 &&
        !content.contains("\0") && !contact.contains("\0")
    }
    func message(version: String, system: String) -> String {
        var lines = ["反馈类型：" + category, "", content.trimmingCharacters(in: .whitespacesAndNewlines)]
        let contact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        if !contact.isEmpty { lines += ["", "联系方式：" + contact] }
        if includesVersion { lines += ["", "应用版本：" + version, "macOS版本：" + system] }
        return lines.joined(separator: "\n")
    }
    func payload(version: String, system: String) -> SupportFeedbackPayload {
        SupportFeedbackPayload(id: id.uuidString.lowercased(), category: category,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
            appVersion: includesVersion ? version : nil, systemVersion: includesVersion ? system : nil)
    }
}

struct SupportFeedbackPayload: Codable {
    let id: String
    let category: String
    let content: String
    let contact: String
    let appVersion: String?
    let systemVersion: String?
}

enum SupportFeedbackError: LocalizedError {
    case unavailable, invalid, rejected(Int), invalidReceipt
    var errorDescription: String? {
        switch self {
        case .unavailable: return "反馈服务尚未配置，请先保留或复制内容。"
        case .invalid: return "请检查反馈内容和字数。"
        case .rejected(429): return "提交过于频繁，请稍后重试。内容已保留。"
        case .rejected(409): return "提交编号冲突，请修改内容后重新提交。"
        case .rejected: return "服务暂时无法接收反馈，请稍后重试。内容已保留。"
        case .invalidReceipt: return "未能确认提交结果，请重试；相同内容不会重复保存。"
        }
    }
}

struct SupportFeedbackClient {
    var session: URLSession = .shared
    func submit(_ draft: SupportFeedbackDraft, configuration: AppSupportConfiguration,
                version: String, system: String) async throws -> String {
        guard draft.isValid else { throw SupportFeedbackError.invalid }
        guard let url = configuration.feedbackURL else { throw SupportFeedbackError.unavailable }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(draft.payload(version: version, system: system))
        // Do not send cookies or follow redirects to a different service with the feedback body.
        let delegate = FeedbackRedirectDelegate()
        let (data, response) = try await session.data(for: request, delegate: delegate)
        guard let response = response as? HTTPURLResponse else { throw SupportFeedbackError.invalidReceipt }
        guard [200, 201].contains(response.statusCode) else { throw SupportFeedbackError.rejected(response.statusCode) }
        struct Receipt: Decodable { let id: String; let accepted: Bool }
        guard let receipt = try? JSONDecoder().decode(Receipt.self, from: data), receipt.accepted,
              receipt.id == draft.id.uuidString.lowercased() else { throw SupportFeedbackError.invalidReceipt }
        return receipt.id
    }
}

private final class FeedbackRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
