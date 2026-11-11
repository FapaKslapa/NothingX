import AudioToolbox
import CoreAudio
import Foundation

final class SystemAudioTap {

    typealias Writer = (_ left: UnsafePointer<Float>, _ right: UnsafePointer<Float>, _ frames: Int) -> Void

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let tapName: String
    private let aggregateName: String

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let ioQueue: DispatchQueue
    private var tapUUID = UUID()

    init(tapName: String, aggregateName: String, queueLabel: String) {
        self.tapName = tapName
        self.aggregateName = aggregateName
        ioQueue = DispatchQueue(label: queueLabel, qos: .userInteractive)
    }

    func prepare() throws -> Double {
        try createTap(excludingOwnProcess: true)
        try createAggregate()
        return try tapSampleRate()
    }

    func stop() {
        if let proc = ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, proc)
            AudioDeviceDestroyIOProcID(aggregateID, proc)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private func createTap(excludingOwnProcess: Bool) throws {
        var excluded: [AudioObjectID] = []
        if excludingOwnProcess, let own = AudioDevices.processObject(for: getpid()) { excluded = [own] }
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.name = tapName
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        var id = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &id)
        guard status == noErr else {
            throw Failure(message: String(format: String(localized: "System audio capture failed (%d)"), Int(status)))
        }
        tapID = id
        tapUUID = description.uuid
    }

    private func createAggregate() throws {
        let dictionary: [String: Any] = [
            kAudioAggregateDeviceNameKey: aggregateName,
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: tapUUID.uuidString,
            ]],
        ]
        var id = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(dictionary as CFDictionary, &id)
        guard status == noErr else {
            throw Failure(message: String(format: String(localized: "Audio routing failed (%d)"), Int(status)))
        }
        aggregateID = id
    }

    private func tapSampleRate() throws -> Double {
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format)
        guard status == noErr, format.mSampleRate > 0 else {
            throw Failure(message: String(format: String(localized: "System audio capture failed (%d)"), Int(status)))
        }
        return format.mSampleRate
    }

    func startIO(_ write: @escaping Writer) throws {
        var scratchL = [Float](repeating: 0, count: 16384)
        var scratchR = [Float](repeating: 0, count: 16384)
        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, ioQueue) { _, inputData, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            guard buffers.count > 0 else { return }
            if buffers.count >= 2 {

                guard let l = buffers[0].mData, let r = buffers[1].mData else { return }
                let frames = Int(buffers[0].mDataByteSize) / MemoryLayout<Float>.size
                write(l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self), frames)
            } else if let data = buffers[0].mData {

                let channels = max(Int(buffers[0].mNumberChannels), 1)
                let frames = min(Int(buffers[0].mDataByteSize) / (MemoryLayout<Float>.size * channels), scratchL.count)
                let samples = data.assumingMemoryBound(to: Float.self)
                for i in 0..<frames {
                    scratchL[i] = samples[i * channels]
                    scratchR[i] = samples[i * channels + (channels > 1 ? 1 : 0)]
                }
                scratchL.withUnsafeBufferPointer { l in
                    scratchR.withUnsafeBufferPointer { r in write(l.baseAddress!, r.baseAddress!, frames) }
                }
            }
        }
        guard status == noErr, let proc = ioProcID else {
            throw Failure(message: String(format: String(localized: "System audio capture failed (%d)"), Int(status)))
        }
        let started = AudioDeviceStart(aggregateID, proc)
        guard started == noErr else {
            throw Failure(message: String(format: String(localized: "System audio capture failed (%d)"), Int(started)))
        }
    }
}
