import Foundation
import AVFoundation
struct AudioSelection: Sendable, Equatable {
 var start: TimeInterval
 var end: TimeInterval
 var duration: TimeInterval { max(0, end - start) }
}
@main struct Harness {
 static func main() async throws {
  let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
  for (name, start, end) in [("exact", 0.025, 0.075), ("empty", 0.05, 0.05), ("pastEnd", 0.2, 0.3), ("overEnd", 0.075, 0.2), ("fractional", 1200.9/48000.0, 3600.9/48000.0)] {
   do {
    try await AudioExporter().export(sourceURL: root.appendingPathComponent("source.wav"), destinationURL: root.appendingPathComponent(name + ".wav"), selection: AudioSelection(start: start, end: end))
    let result = try AVAudioFile(forReading: root.appendingPathComponent(name + ".wav"))
    print("\(name): success frames=\(result.length) channels=\(result.processingFormat.channelCount) settings=\(result.fileFormat.settings)")
   } catch { print("\(name): error \(error)") }
  }
 }
}
