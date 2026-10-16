import AVFoundation
import Foundation

actor AudioExporter {
    enum ExportError: LocalizedError {
        case emptySelection
        case couldNotCreateBuffer

        var errorDescription: String? {
            switch self {
            case .emptySelection: "The marked selection is empty."
            case .couldNotCreateBuffer: "Could not allocate an audio export buffer."
            }
        }
    }

    func export(sourceURL: URL, destinationURL: URL, selection: AudioSelection) throws {
        let source = try AVAudioFile(forReading: sourceURL)
        let sampleRate = source.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(selection.start * sampleRate)
        let endFrame = min(source.length, AVAudioFramePosition(selection.end * sampleRate))
        guard endFrame > startFrame else { throw ExportError.emptySelection }

        let destination = try AVAudioFile(
            forWriting: destinationURL,
            settings: source.fileFormat.settings,
            commonFormat: source.processingFormat.commonFormat,
            interleaved: source.processingFormat.isInterleaved
        )
        source.framePosition = startFrame

        let capacity: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: source.processingFormat,
            frameCapacity: capacity
        ) else { throw ExportError.couldNotCreateBuffer }

        var remaining = endFrame - startFrame
        while remaining > 0 {
            let requested = AVAudioFrameCount(min(AVAudioFramePosition(capacity), remaining))
            try source.read(into: buffer, frameCount: requested)
            guard buffer.frameLength > 0 else { break }
            try destination.write(from: buffer)
            remaining -= AVAudioFramePosition(buffer.frameLength)
        }
    }
}
