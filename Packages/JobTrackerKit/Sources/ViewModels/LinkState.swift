import Domain

/// What the link field shows about the pasted posting.
///
/// One enum, so the sheet can never show two states at once, such as fetching and couldn't read.
public enum LinkState: Equatable, Sendable {
    /// No fetchable link, or a link waiting out the debounce.
    case idle
    /// The posting is being fetched. The form stays editable.
    case fetching
    /// The posting was read. Blank fields were filled in from it.
    case found(PostingMetadata)
    /// The posting couldn't be read: a sign-in page, a timeout, or nothing usable. The link is still saved.
    case couldNotRead
}
