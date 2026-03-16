import Cocoa
import CoreGraphics
import os.log

class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    private var eventPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    var onVolumeUp: ((Bool) -> Void)?
    var onVolumeDown: ((Bool) -> Void)?
    var onMuteToggle: (() -> Void)?
    var onBrightnessUp: ((Bool) -> Void)?
    var onBrightnessDown: ((Bool) -> Void)?
    var shouldInterceptBrightnessKeys: (() -> Bool)?
    
    private init() {}
    
    func start() {
        if eventPort != nil {
            return
        }

        // Require Accessibility Permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            os_log("Accessibility access denied. Please enable in System Preferences -> Security & Privacy -> Accessibility")
            // Optionally, show an alert to the user here
        }
        
        let eventMask = (1 << 14) // 14 is NX_SYSDEFINED
        
        eventPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                
                if type.rawValue == 14 { // NX_SYSDEFINED
                    let nsEvent = NSEvent(cgEvent: event)
                    
                    // 8 is the subtype for media keys
                    if nsEvent?.subtype.rawValue == 8 {
                        let data1 = nsEvent?.data1 ?? 0
                        let keyCode = (data1 & 0xFFFF0000) >> 16
                        let keyFlags = (data1 & 0x0000FFFF)
                        let keyState = (((keyFlags & 0xFF00) >> 8) == 0xA) // Key down
                        let keyRepeat = (keyFlags & 0x1)
                        
                        let flags = event.flags
                        let isFineControl = flags.contains(.maskAlternate) && flags.contains(.maskShift)
                        
                        // Proceed only on key down or repeat
                        if keyState || keyRepeat != 0 {
                            let interceptor = MediaKeyInterceptor.shared
                            
                            switch keyCode {
                            case 0: // Volume Up (NX_KEYTYPE_SOUND_UP)
                                DispatchQueue.main.async { interceptor.onVolumeUp?(isFineControl) }
                                return nil // Swallow the event!
                            case 1: // Volume Down (NX_KEYTYPE_SOUND_DOWN)
                                DispatchQueue.main.async { interceptor.onVolumeDown?(isFineControl) }
                                return nil // Swallow the event!
                            case 2: // Brightness Up (NX_KEYTYPE_BRIGHTNESS_UP)
                                guard interceptor.shouldInterceptBrightnessKeys?() ?? false else {
                                    break
                                }
                                DispatchQueue.main.async { interceptor.onBrightnessUp?(isFineControl) }
                                return nil // Swallow the event!
                            case 3: // Brightness Down (NX_KEYTYPE_BRIGHTNESS_DOWN)
                                guard interceptor.shouldInterceptBrightnessKeys?() ?? false else {
                                    break
                                }
                                DispatchQueue.main.async { interceptor.onBrightnessDown?(isFineControl) }
                                return nil // Swallow the event!
                            case 7: // Mute (NX_KEYTYPE_MUTE)
                                DispatchQueue.main.async { interceptor.onMuteToggle?() }
                                return nil // Swallow the event!
                            default:
                                break
                            }
                        }
                    }
                }
                
                // For all other events, pass them through
                return Unmanaged.passRetained(event)
                
            }, userInfo: nil)
        
        guard let port = eventPort else {
            os_log("Failed to create event tap. Make sure the app has Accessibility permissions.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func refreshPermissionState() {
        if AXIsProcessTrusted() {
            if eventPort == nil {
                start()
            }
        } else {
            stop()
        }
    }
    
    func stop() {
        if let port = eventPort {
            CGEvent.tapEnable(tap: port, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            self.eventPort = nil
            self.runLoopSource = nil
        }
    }
}
