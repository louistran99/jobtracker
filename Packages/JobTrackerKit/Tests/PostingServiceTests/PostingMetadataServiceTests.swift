import Domain
import Foundation
import Testing

@testable import PostingService

struct PostingMetadataServiceTests {
    private let service = PostingMetadataService(
        session: StubURLProtocol.makeSession(),
        timeZone: PostingParserTests.timeZone
    )

    @Test func readsTheSavedAshbyPosting() async throws {
        let url = StubURLProtocol.register(.init(body: try Fixture.ashbyPage()))

        let metadata = try await service.metadata(for: url)

        #expect(metadata.role == "Engineering Manager, Momentum")
        #expect(metadata.company == "Grow Therapy")
        let summary = metadata.summary(locale: Locale(identifier: "en_US"), timeZone: PostingParserTests.timeZone)
        #expect(summary == "New York · Remote · Posted Jul 2")
    }

    @Test(arguments: [403, 404, 429, 999])
    func anErrorStatusCantBeRead(status: Int) async {
        let url = StubURLProtocol.register(.init(status: status, body: Data("<title>EM @ Stripe</title>".utf8)))
        await #expect(throws: PostingFetchError.httpStatus(status)) {
            try await service.metadata(for: url)
        }
    }

    @Test func aRedirectToSignInIsALoginWall() async throws {
        let authwall = try #require(URL(string: "https://www.linkedin.com/authwall?trk=job"))
        let body = Data("<html><head><title>LinkedIn</title></head></html>".utf8)
        let url = StubURLProtocol.register(.init(body: body, finalURL: authwall))
        await #expect(throws: PostingFetchError.loginWall) {
            try await service.metadata(for: url)
        }
    }

    @Test func aNonPageResponseIsRejected() async {
        let url = StubURLProtocol.register(.init(headers: ["Content-Type": "application/pdf"], body: Data([0x25])))
        await #expect(throws: PostingFetchError.unsupportedContentType("application/pdf")) {
            try await service.metadata(for: url)
        }
    }

    @Test func anOversizeBodyIsRejected() async {
        let body = Data(repeating: 0x20, count: PostingMetadataService.maximumBodySize + 1)
        let url = StubURLProtocol.register(.init(body: body))
        await #expect(throws: PostingFetchError.tooLarge) {
            try await service.metadata(for: url)
        }
    }

    @Test func anOversizeContentLengthIsRejectedBeforeDownloading() async {
        let length = String(PostingMetadataService.maximumBodySize + 1)
        let url = StubURLProtocol.register(.init(headers: ["Content-Type": "text/html", "Content-Length": length]))
        await #expect(throws: PostingFetchError.tooLarge) {
            try await service.metadata(for: url)
        }
    }

    @Test func cancellingThrowsCancellationError() async {
        let (started, starting) = AsyncStream.makeStream(of: Void.self)
        let url = StubURLProtocol.register(.init(hang: { starting.yield() }))
        let service = service
        let fetch = Task { try await service.metadata(for: url) }

        var iterator = started.makeAsyncIterator()
        _ = await iterator.next()
        fetch.cancel()

        await #expect(throws: CancellationError.self) {
            try await fetch.value
        }
    }
}
