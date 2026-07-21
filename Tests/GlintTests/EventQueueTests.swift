import XCTest
@testable import Glint

final class EventQueueTests: XCTestCase {
    func testGuardianAndOtherSubagentsNeverCountAsUserTaskCompletion() {
        let guardian: [String: Any] = ["subagent": ["other": "guardian"]]
        XCTAssertNil(CodexDesktopWatcher.bundleIdentifier(for: "Codex Desktop", source: guardian))
        XCTAssertEqual(CodexDesktopWatcher.bundleIdentifier(for: "Codex Desktop", source: "vscode"), "com.openai.codex")
    }

    func testDoneOnlyRejectsProgressFromEveryAdapter() {
        let progress = GlintEvent(source: "future-adapter", title: "Still working", detail: "Step 2", status: "progress")
        XCTAssertFalse(NotificationPolicy.shouldDisplay(progress, mode: "doneOnly"))
        XCTAssertTrue(NotificationPolicy.shouldDisplay(progress, mode: "steps"))
    }

    func testDoneOnlyAllowsTerminalAndDismissEvents() {
        for status in ["success", "failure", "cancelled", "dismiss"] {
            let event = GlintEvent(source: "test", title: "Event", detail: "Detail", status: status)
            XCTAssertTrue(NotificationPolicy.shouldDisplay(event, mode: "doneOnly"), status)
        }
    }

    override class func setUp() {
        super.setUp()
        setenv("GLINT_DATA_DIR", FileManager.default.temporaryDirectory
            .appendingPathComponent("GlintTests-\(UUID().uuidString)").path, 1)
    }

    func testConcurrentProducersCreateCompletePrivateRecords() throws {
        let total = 80
        DispatchQueue.concurrentPerform(iterations: total) { index in
            try! EventQueue.push(GlintEvent(source: "test", title: "Event \(index)", detail: "complete"))
        }

        let events = EventQueue.drain(limit: total + 1)
        XCTAssertEqual(events.count, total)
        XCTAssertEqual(Set(events.map(\.id)).count, total)
        XCTAssertTrue((try FileManager.default.contentsOfDirectory(at: GlintPaths.inbox,
                                                                   includingPropertiesForKeys: nil)).isEmpty)
        let permissions = try FileManager.default.attributesOfItem(atPath: GlintPaths.inbox.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue ?? 0, 0o700)
    }

    func testOldConfigDefaultsToDoneOnly() throws {
        let data = Data(#"{"sound":"Glass","theme":"ember","position":"top-right","duration":0,"enabled":true}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(GlintConfig.self, from: data).notificationMode, "doneOnly")
    }
}
