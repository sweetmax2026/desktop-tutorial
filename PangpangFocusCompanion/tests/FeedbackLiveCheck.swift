import Foundation

// Explicit opt-in live check; never reads formal app preferences or records.
@main enum FeedbackLiveCheck {
    static func main() async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["PANG_FEEDBACK_LIVE_URL"],
              endpoint == "https://pang-feedback.maxwithcoconut.workers.dev/api/feedback" else {
            throw SupportFeedbackError.unavailable
        }
        let configuration = AppSupportConfiguration(info: ["PangFeedbackURL": endpoint])
        var draft = SupportFeedbackDraft()
        draft.category = "其他"
        draft.content = "【自动联调测试】Swift URLSession合成反馈，不来自真实用户，验证后删除。"
        draft.includesVersion = false
        let id = try await SupportFeedbackClient().submit(draft, configuration: configuration, version: "", system: "")
        let retry = try await SupportFeedbackClient().submit(draft, configuration: configuration, version: "", system: "")
        precondition(retry == id)
        print(id)
    }
}
