import Foundation
import CoreAudio
import Combine

let volumeListenerProc: AudioObjectPropertyListenerProc = { (id, addressCount, addresses, context) -> OSStatus in
    if let context = context {
        let manager = Unmanaged<VolumeManager>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async {
            // Only show HUD from the listener if WE didn't just set the volume ourselves.
            // changeVolume() sets isChangingVolume = true and already calls showHUD().
            // This prevents duplicate renders and flickering from the double-callback.
            let previousVolume = manager.volume
            manager.updateVolume()
            let changed = abs(manager.volume - previousVolume) > 0.005
            if !manager.isChangingVolume && changed {
                HUDWindowManager.shared.showHUD(volumeManager: manager)
            }
            manager.isChangingVolume = false
        }
    }
    return noErr
}

let muteListenerProc: AudioObjectPropertyListenerProc = { (id, addressCount, addresses, context) -> OSStatus in
    if let context = context {
        let manager = Unmanaged<VolumeManager>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async {
            let previousMute = manager.isMuted
            manager.updateMuteStatus()
            if !manager.isChangingVolume || manager.isMuted != previousMute {
                HUDWindowManager.shared.showHUD(volumeManager: manager)
            }
        }
    }
    return noErr
}

let defaultDeviceListenerProc: AudioObjectPropertyListenerProc = { (id, addressCount, addresses, context) -> OSStatus in
    if let context = context {
        let manager = Unmanaged<VolumeManager>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async {
            manager.handleDefaultDeviceChange()
        }
    }
    return noErr
}

class VolumeManager: ObservableObject {
    @Published var volume: Float = 0.0
    @Published var isMuted: Bool = false
    @Published var activeDeviceName: String = "Unknown"
    
    /// Set to true right before we change volume ourselves so the CoreAudio
    /// listener callback knows not to call showHUD a second time.
    var isChangingVolume: Bool = false
    
    private var currentDeviceID: AudioObjectID = kAudioObjectUnknown
    private var currentSystemDeviceID: AudioObjectID = kAudioObjectUnknown
    private let channels: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
    private let totalVolumeSteps = 64
    private let normalStepCount = 4
    private let fineStepCount = 1

    init() {
        setupDefaultDeviceListener()
        handleDefaultDeviceChange()
        
        // Setup Media Key Interceptor
        MediaKeyInterceptor.shared.onVolumeUp = { [weak self] isFineControl in
            guard let self else { return }
            self.changeVolume(stepCount: isFineControl ? self.fineStepCount : self.normalStepCount)
        }
        MediaKeyInterceptor.shared.onVolumeDown = { [weak self] isFineControl in
            guard let self else { return }
            self.changeVolume(stepCount: -(isFineControl ? self.fineStepCount : self.normalStepCount))
        }
        MediaKeyInterceptor.shared.onMuteToggle = { [weak self] in
            self?.toggleMute()
        }
        MediaKeyInterceptor.shared.start()
    }
    
    deinit {
        removeListeners()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, defaultDeviceListenerProc, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }

    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, defaultDeviceListenerProc, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }

    func handleDefaultDeviceChange() {
        removeListeners()
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var newDeviceID: AudioObjectID = kAudioObjectUnknown
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &newDeviceID)
        
        if status == noErr {
            currentDeviceID = newDeviceID
            
            var sysAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var sysDeviceID: AudioObjectID = kAudioObjectUnknown
            let sysStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &sysAddress, 0, nil, &size, &sysDeviceID)
            if sysStatus == noErr {
                currentSystemDeviceID = sysDeviceID
            }
            
            updateDeviceName()
            addListeners()
            updateVolume()
            updateMuteStatus()
        }
    }

    private func addListeners() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let deviceIDs = [currentDeviceID, currentSystemDeviceID].filter { $0 != kAudioObjectUnknown }
        let uniqueDevices = Array(Set(deviceIDs))
        
        for device in uniqueDevices {
            for channel in channels {
                var volAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
                var muteAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
                
                // Add listeners without checking HasProperty, as it's safe to add and guarantees we catch events if they start firing
                AudioObjectAddPropertyListener(device, &volAddress, volumeListenerProc, context)
                AudioObjectAddPropertyListener(device, &muteAddress, muteListenerProc, context)
            }
        }
    }
    
    private func removeListeners() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let deviceIDs = [currentDeviceID, currentSystemDeviceID].filter { $0 != kAudioObjectUnknown }
        let uniqueDevices = Array(Set(deviceIDs))
        
        for device in uniqueDevices {
            for channel in channels {
                var volAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
                var muteAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
                
                AudioObjectRemovePropertyListener(device, &volAddress, volumeListenerProc, context)
                AudioObjectRemovePropertyListener(device, &muteAddress, muteListenerProc, context)
            }
        }
    }

    private func updateDeviceName() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &name)
        if status == noErr, let name = name {
            self.activeDeviceName = name as String
        }
    }

    func updateVolume() {
        var vol: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        var foundValidVol = false
        
        for channel in channels {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            
            if AudioObjectHasProperty(currentDeviceID, &address) {
                let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &vol)
                if status == noErr {
                    let newVol = quantizedVolume(Float(vol))
                    if abs(self.volume - newVol) > 0.001 {
                        self.volume = newVol
                    }
                    foundValidVol = true
                    break
                }
            }
        }
        
        if !foundValidVol && currentSystemDeviceID != kAudioObjectUnknown {
            for channel in channels {
                var volAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: channel
                )
                if AudioObjectHasProperty(currentSystemDeviceID, &volAddress) {
                    let volStatus = AudioObjectGetPropertyData(currentSystemDeviceID, &volAddress, 0, nil, &size, &vol)
                    if volStatus == noErr {
                         let newVol = quantizedVolume(Float(vol))
                         if abs(self.volume - newVol) > 0.001 {
                            self.volume = newVol
                         }
                         foundValidVol = true
                         break
                    }
                }
            }
        }
    }
    
    func updateMuteStatus() {
        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var foundMute = false
        
        for channel in channels {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            if AudioObjectHasProperty(currentDeviceID, &address) {
                let status = AudioObjectGetPropertyData(currentDeviceID, &address, 0, nil, &size, &mute)
                if status == noErr {
                    let newMute = (mute != 0)
                    if self.isMuted != newMute {
                        self.isMuted = newMute
                    }
                    foundMute = true
                    break
                }
            }
        }
        
        if !foundMute && currentSystemDeviceID != kAudioObjectUnknown {
            for channel in channels {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: channel
                )
                if AudioObjectHasProperty(currentSystemDeviceID, &address) {
                    let status = AudioObjectGetPropertyData(currentSystemDeviceID, &address, 0, nil, &size, &mute)
                    if status == noErr {
                        let newMute = (mute != 0)
                        if self.isMuted != newMute {
                            self.isMuted = newMute
                        }
                        foundMute = true
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Volume Control (for Interceptor)
    
    func changeVolume(stepCount: Int) {
        let currentStep = quantizedStep(for: self.volume)
        let newStep = max(0, min(totalVolumeSteps, currentStep + stepCount))
        let newVolume = Float(newStep) / Float(totalVolumeSteps)
        
        // Update local state immediately for responsive UI
        self.volume = newVolume
        HUDWindowManager.shared.showHUD(volumeManager: self)
        
        // Mark that WE are changing the volume so the CoreAudio listener
        // callback knows to skip its showHUD call (prevents double render / flicker)
        self.isChangingVolume = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let percent = Int(round(newVolume * 100))
            let script = "set volume output volume \(percent)"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
        
        if self.isMuted && stepCount > 0 {
            toggleMute(forceState: false, showHUD: false)
        }
    }
    
    func toggleMute(forceState: Bool? = nil, showHUD: Bool = true) {
        let newState = forceState ?? !self.isMuted
        
        // Update local state immediately
        self.isMuted = newState
        if showHUD {
            HUDWindowManager.shared.showHUD(volumeManager: self)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "set volume output muted \(newState ? "true" : "false")"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }

    private func quantizedStep(for volume: Float) -> Int {
        Int(round(Double(volume) * Double(totalVolumeSteps)))
    }

    private func quantizedVolume(_ rawVolume: Float) -> Float {
        Float(max(0, min(totalVolumeSteps, quantizedStep(for: rawVolume)))) / Float(totalVolumeSteps)
    }
}
