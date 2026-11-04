import Testing

@testable import Domain

struct StageTests {
    @Test func hasTheFiveStagesInPickerOrder() {
        #expect(Stage.allCases == [.applied, .screening, .onsite, .offer, .rejected])
        #expect(Stage.allCases.map(\.title) == ["Applied", "Screening", "Onsite", "Offer", "Rejected"])
    }
}
