import Foundation
import Synchronization

/// Serves canned responses to a `URLSession`, so service tests never touch the network.
///
/// Stubs are keyed by URL, and each test registers its own unique URL, so tests can run in parallel.
final class StubURLProtocol: URLProtocol {
    struct Stub: Sendable {
        var status = 200
        var headers = ["Content-Type": "text/html; charset=utf-8"]
        var body = Data()
        /// The URL the response reports, as after a redirect. Defaults to the requested URL.
        var finalURL: URL?
        /// When set, the request never answers and calls this once loading starts.
        var hang: (@Sendable () -> Void)?
    }

    private static let stubs = Mutex<[URL: Stub]>([:])

    static func register(_ stub: Stub) -> URL {
        let url = URL(string: "https://stub.example.com/\(UUID().uuidString)") ?? URL(filePath: "/")
        stubs.withLock { $0[url] = stub }
        return url
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.stubs.withLock({ $0[url] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        if let hang = stub.hang {
            hang()
            return
        }
        guard
            let response = HTTPURLResponse(
                url: stub.finalURL ?? url,
                statusCode: stub.status,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
