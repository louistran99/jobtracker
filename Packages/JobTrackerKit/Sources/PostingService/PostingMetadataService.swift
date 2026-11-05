import Domain
import Foundation
import os

/// Fetches a job posting and reads its role and company.
///
/// An actor, so the download and the parse never run on the main actor, whatever the caller's isolation.
public actor PostingMetadataService {
    /// Postings are a few hundred kilobytes at most. Anything larger is not a posting page.
    public static let maximumBodySize = 5 * 1024 * 1024

    private static let timeout: TimeInterval = 10
    private static let accept = "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8"

    private let session: URLSession
    private let timeZone: TimeZone

    /// - Parameters:
    ///   - session: The session that downloads postings. Tests pass one backed by a stub `URLProtocol`.
    ///   - timeZone: The time zone that date-only posting dates are read in.
    public init(session: URLSession = .shared, timeZone: TimeZone = .current) {
        self.session = session
        self.timeZone = timeZone
    }

    /// Downloads `url` and reads the posting.
    ///
    /// - Throws: `PostingFetchError` when the posting can't be read, `CancellationError` when the calling task is
    ///   cancelled, or a `URLError` for a network failure.
    public func metadata(for url: URL) async throws -> PostingMetadata {
        do {
            let (body, response) = try await download(url)
            return try PostingParser.parse(
                body: body,
                contentType: response.value(forHTTPHeaderField: "Content-Type"),
                textEncodingName: response.textEncodingName,
                finalURL: response.url,
                timeZone: timeZone
            )
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Logger.postingService.notice(
                "Couldn't read \(url.absoluteString, privacy: .private): \(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    private func download(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue(Self.accept, forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(response.statusCode) else {
            throw PostingFetchError.httpStatus(response.statusCode)
        }
        if let contentType = response.mimeType, !Self.isReadable(contentType) {
            throw PostingFetchError.unsupportedContentType(contentType)
        }
        if response.expectedContentLength > Self.maximumBodySize {
            throw PostingFetchError.tooLarge
        }

        var body = Data()
        body.reserveCapacity(Int(clamping: max(response.expectedContentLength, 0)))
        for try await byte in bytes {
            guard body.count < Self.maximumBodySize else { throw PostingFetchError.tooLarge }
            body.append(byte)
        }
        try Task.checkCancellation()
        return (body, response)
    }

    private static func isReadable(_ mimeType: String) -> Bool {
        let type = mimeType.lowercased()
        return type.hasPrefix("text/") || type.contains("html") || type.contains("json") || type.contains("xml")
    }
}

extension Logger {
    fileprivate static let postingService = Logger(subsystem: "com.louistran.jobtracker", category: "posting-service")
}
