import Testing
import PrestoCVPresentation

/// Where the form is short of room (a compact height, as in landscape on an iPhone, or an accessibility text size), the
/// notice above it takes at most a quarter of the editor's height and scrolls inside; elsewhere it takes what it needs
/// (#402, decision 9).
@Suite("Notice share of the editor's height")
struct NoticeShareTests {

    private static let portrait = EditorChrome(isCompactHeight: false, isAccessibilitySize: false)
    private static let landscape = EditorChrome(isCompactHeight: true, isAccessibilitySize: false)
    private static let largestText = EditorChrome(isCompactHeight: false, isAccessibilitySize: true)

    @Test("the notice share is a quarter of the editor's height where the form is short of room")
    func noticeShareIsAQuarterWhereShortOfRoom() {
        #expect(EditorChrome.noticeShareOfHeight == 0.25)
        #expect(Self.largestText.noticeHeight(fullHeight: 400, editorHeight: 760) == 190)
        #expect(Self.landscape.noticeHeight(fullHeight: 200, editorHeight: 320) == 80)
    }

    @Test("a regular height at a regular text size gives the notice all it needs")
    func portraitIsNotCapped() {
        #expect(!Self.portrait.isShortOfRoom)
        #expect(Self.portrait.noticeHeight(fullHeight: 400, editorHeight: 760) == nil)
    }

    @Test("a notice shorter than its share keeps its own height")
    func shortNoticeKeepsItsHeight() {
        #expect(Self.largestText.noticeHeight(fullHeight: 120, editorHeight: 760) == 120)
    }

    @Test("before the editor's height is known, nothing is capped")
    func unknownEditorHeightIsNotCapped() {
        #expect(Self.largestText.noticeHeight(fullHeight: 400, editorHeight: 0) == nil)
    }

    @Test("a compact height or an accessibility text size is short of room, and both together too")
    func shortOfRoom() {
        #expect(Self.landscape.isShortOfRoom)
        #expect(Self.largestText.isShortOfRoom)
        #expect(EditorChrome(isCompactHeight: true, isAccessibilitySize: true).isShortOfRoom)
    }
}
