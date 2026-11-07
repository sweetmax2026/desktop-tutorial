import Foundation

private final class FeedbackMockProtocol: URLProtocol {
    static var statusCode = 201
    static var mismatchedReceipt = false
    static var networkFailure = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if Self.networkFailure { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        precondition(request.httpMethod == "POST" && request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
            body = data
        }
        let payload = try! JSONDecoder().decode(SupportFeedbackPayload.self, from: body!)
        precondition(payload.appVersion == nil && payload.systemVersion == nil)
        let id = Self.mismatchedReceipt ? UUID().uuidString : payload.id
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: ["id": id, "accepted": true]))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main enum AppSupportChecks {
    static func main() async throws {
        let configuration = AppSupportConfiguration(info: ["PangFeedbackURL": "https://feedback.example.invalid/api/feedback"])
        precondition(configuration.feedbackURL != nil && configuration.productURL == nil)
        for endpoint in ["", "http://example.com", "https://user:pass@example.com", "https://example.com?secret=x", "https://example.com#x"] {
            precondition(AppSupportConfiguration(info: ["PangFeedbackURL": endpoint]).feedbackURL == nil)
        }
        var draft = SupportFeedbackDraft(); precondition(!draft.isValid)
        draft.content = "中文 + emoji 🐱 & ? #\n第二行"; draft.contact = "reply+test@example.invalid"
        let stableID = draft.id
        precondition(draft.isValid && draft.id == stableID)
        draft.includesVersion = false
        precondition(draft.id != stableID)
        precondition(!draft.message(version: "DO_NOT_INCLUDE_APP", system: "DO_NOT_INCLUDE_OS").contains("DO_NOT_INCLUDE"))
        let payload = draft.payload(version: "1", system: "2")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        precondition(Set(json.keys) == Set(["id", "category", "content", "contact"]))
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [FeedbackMockProtocol.self]
        let client = SupportFeedbackClient(session: URLSession(configuration: sessionConfig))
        let snapshot = draft
        for code in [201, 200] {
            FeedbackMockProtocol.statusCode = code
            let id = try await client.submit(draft, configuration: configuration, version: "1", system: "2")
            precondition(id == draft.id.uuidString.lowercased())
        }
        for code in [400, 409, 429, 500, 302] {
            FeedbackMockProtocol.statusCode = code
            do { _ = try await client.submit(draft, configuration: configuration, version: "1", system: "2"); preconditionFailure("Must reject HTTP error") } catch { precondition(draft == snapshot) }
        }
        FeedbackMockProtocol.statusCode = 201; FeedbackMockProtocol.mismatchedReceipt = true
        do { _ = try await client.submit(draft, configuration: configuration, version: "1", system: "2"); preconditionFailure("Must reject incorrect receipt") } catch { precondition(draft == snapshot) }
        FeedbackMockProtocol.networkFailure = true
        do { _ = try await client.submit(draft, configuration: configuration, version: "1", system: "2"); preconditionFailure("Must preserve draft offline") } catch { precondition(draft == snapshot) }
        draft.content = " \n "; precondition(!draft.isValid)
        draft.content = String(repeating: "字", count: 2001); precondition(!draft.isValid)
        draft.content = "正常内容"; draft.contact = String(repeating: "x", count: 201); precondition(!draft.isValid)
        precondition(AppSupportConfiguration(info: ["PangAppStoreID": "123456789"]).productURL?.absoluteString == "https://apps.apple.com/app/id123456789")
        for invalid in ["", "https://example.com", "123?x=y", "../123", "１２３"] {
            precondition(AppSupportConfiguration(info: ["PangAppStoreID": invalid]).productURL == nil)
        }
        print("PASS: HTTPS configuration, minimal payload, optional versions, stable retry ID, receipts, server/network errors preserve draft")
        print("PASS: optional App Store ID; no real feedback or store request sent")
    }
}
