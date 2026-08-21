import Foundation
import Combine
import IOKit.ps
import CoreAudio

@MainActor
public final class SystemStatusService: ObservableObject {
    public static let shared = SystemStatusService()

    @Published public private(set) var currentDate = Date()
    @Published public private(set) var batteryLevel: Int = 100
    @Published public private(set) var isCharging: Bool = false
    @Published public private(set) var hasBattery: Bool = true
    @Published public var volume: Float = 0.5
    @Published public var isMuted: Bool = false

    private var timer: Timer?

    private init() {
        updateTime()
        updateBattery()
        updateVolume()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTime()
                self?.updateBattery()
            }
        }
    }

    private func updateTime() {
        self.currentDate = Date()
    }

    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            self.hasBattery = false
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let current = description[kIOPSCurrentCapacityKey] as? Int,
               let max = description[kIOPSMaxCapacityKey] as? Int,
               max > 0 {
                self.batteryLevel = Int((Double(current) / Double(max)) * 100.0)
                self.hasBattery = true
            }

            if let isCharging = description[kIOPSIsChargingKey] as? Bool {
                self.isCharging = isCharging
            }
        }
    }

    public func updateVolume() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        guard status == noErr, defaultOutputDeviceID != 0 else { return }

        var volume: Float32 = 0.0
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectGetPropertyData(defaultOutputDeviceID, &volumeAddress, 0, nil, &volumeSize, &volume) == noErr {
            self.volume = volume
        }

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, &muteSize, &mute) == noErr {
            self.isMuted = (mute != 0)
        }
    }

    public func setVolume(_ newVolume: Float) {
        self.volume = newVolume
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        guard status == noErr, defaultOutputDeviceID != 0 else { return }

        var vol = Float32(newVolume)
        let volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, volSize, &vol)
    }

    public func toggleMute() {
        let newMute = !self.isMuted
        self.isMuted = newMute

        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultOutputDeviceID) == noErr else { return }

        var muteVal: UInt32 = newMute ? 1 : 0
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, muteSize, &muteVal)
    }
}
