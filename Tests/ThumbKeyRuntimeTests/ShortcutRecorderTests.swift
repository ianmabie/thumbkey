import AppKit
import XCTest
@testable import ThumbKey
import ThumbKeyCore
final class ShortcutRecorderTests: XCTestCase {
    func testNativeRecorderCapturesShortcutAndResumesAfterFinishing() async {
        await MainActor.run {
            _ = NSApplication.shared
            let recorder = ShortcutRecorder.Recorder()
            var recordingChanges = [Bool]()
            var captured: Chord?
            recorder.recordingChanged = { recordingChanges.append($0) }
            recorder.changed = { captured = $0 }
            recorder.beginRecording()
            XCTAssertTrue(recorder.recording)
            let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0, windowNumber: 0, context: nil, characters: "d", charactersIgnoringModifiers: "d", isARepeat: false, keyCode: 2)!
            recorder.keyDown(with: key)
            XCTAssertEqual(captured?.keyCode, 2)
            XCTAssertFalse(recorder.recording)
            XCTAssertEqual(recordingChanges, [true, false])
            recorder.beginRecording()
            recorder.canRecord = false
            XCTAssertFalse(recorder.recording)
            recorder.beginRecording()
            XCTAssertFalse(recorder.recording, "Disabled native controls cannot start key capture")
            XCTAssertEqual(recordingChanges, [true, false, true, false])
        }
    }
    func testRightCommandStillRecordsAsAPhysicalModifierKey() async {
        await MainActor.run {
            _ = NSApplication.shared
            let recorder = ShortcutRecorder.Recorder()
            var captured: Chord?
            recorder.changed = { captured = $0 }
            recorder.beginRecording()
            let down = NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 54)!
            let up = NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 54)!
            recorder.flagsChanged(with: down); recorder.flagsChanged(with: up)
            XCTAssertEqual(captured?.keyCode, 54)
            XCTAssertEqual(captured?.modifiers, [])
            XCTAssertFalse(recorder.recording)
        }
    }
    func testEscapeAndFocusLossCancelWithoutChangingShortcut() async {
        await MainActor.run {
            _ = NSApplication.shared
            let recorder = ShortcutRecorder.Recorder()
            var captures = 0
            recorder.changed = { _ in captures += 1 }
            recorder.beginRecording()
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
            recorder.keyDown(with: escape)
            XCTAssertFalse(recorder.recording)
            recorder.beginRecording()
            _ = recorder.resignFirstResponder()
            XCTAssertFalse(recorder.recording)
            XCTAssertEqual(captures, 0)
        }
    }
}
