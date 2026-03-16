import CoreGraphics
import Darwin
import Foundation

final class BrightnessManager {
    static let shared = BrightnessManager()
    static let isEnabledDefaultsKey = "enableBrightnessHUD"

    private let totalBrightnessSteps = 64
    private let normalStepCount = 4
    private let fineStepCount = 1
    private let getBrightness: DisplayServicesGetBrightness?
    private let setBrightness: DisplayServicesSetBrightness?

    private(set) var brightness: Float = 0.0

    var canControlBrightness: Bool {
        getBrightness != nil && setBrightness != nil && currentDisplayID() != 0
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.isEnabledDefaultsKey)
    }

    private init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        let handle = dlopen(frameworkPath, RTLD_LAZY)
        getBrightness = handle.flatMap {
            guard let symbol = dlsym($0, "DisplayServicesGetBrightness") else { return nil }
            return unsafeBitCast(symbol, to: DisplayServicesGetBrightness.self)
        }
        setBrightness = handle.flatMap {
            guard let symbol = dlsym($0, "DisplayServicesSetBrightness") else { return nil }
            return unsafeBitCast(symbol, to: DisplayServicesSetBrightness.self)
        }

        refreshDisplayService()

        MediaKeyInterceptor.shared.shouldInterceptBrightnessKeys = { [weak self] in
            guard let self else { return false }
            return self.isEnabled && self.canControlBrightness
        }
        MediaKeyInterceptor.shared.onBrightnessUp = { [weak self] isFineControl in
            guard let self else { return }
            self.changeBrightness(stepCount: isFineControl ? self.fineStepCount : self.normalStepCount)
        }
        MediaKeyInterceptor.shared.onBrightnessDown = { [weak self] isFineControl in
            guard let self else { return }
            self.changeBrightness(stepCount: -(isFineControl ? self.fineStepCount : self.normalStepCount))
        }
        MediaKeyInterceptor.shared.start()
    }

    func refreshDisplayService() {
        updateBrightness()
    }

    func updateBrightness() {
        guard
            let getBrightness,
            let displayID = controllableDisplayID()
        else {
            brightness = 0.0
            return
        }

        var value: Float = 0.0
        if getBrightness(displayID, &value) == 0 {
            brightness = quantizedBrightness(value)
        }
    }

    func changeBrightness(stepCount: Int) {
        guard
            let setBrightness,
            let displayID = controllableDisplayID()
        else { return }

        let currentStep = quantizedStep(for: brightness)
        let newStep = max(0, min(totalBrightnessSteps, currentStep + stepCount))
        let newBrightness = Float(newStep) / Float(totalBrightnessSteps)

        brightness = newBrightness
        HUDWindowManager.shared.showBrightnessHUD(brightness: newBrightness)

        DispatchQueue.global(qos: .userInitiated).async {
            _ = setBrightness(displayID, newBrightness)
        }
    }

    private func controllableDisplayID() -> CGDirectDisplayID? {
        guard getBrightness != nil else { return nil }

        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else {
            return nil
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return nil
        }

        let mainDisplayID = CGMainDisplayID()
        let orderedDisplayIDs = [mainDisplayID] + displayIDs.filter { $0 != mainDisplayID }

        for displayID in orderedDisplayIDs {
            if canReadBrightness(for: displayID) {
                return displayID
            }
        }

        return nil
    }

    private func currentDisplayID() -> CGDirectDisplayID {
        CGMainDisplayID()
    }

    private func canReadBrightness(for displayID: CGDirectDisplayID) -> Bool {
        guard let getBrightness else { return false }
        var value: Float = 0.0
        return getBrightness(displayID, &value) == 0
    }

    private func quantizedStep(for brightness: Float) -> Int {
        Int(round(Double(brightness) * Double(totalBrightnessSteps)))
    }

    private func quantizedBrightness(_ rawBrightness: Float) -> Float {
        Float(max(0, min(totalBrightnessSteps, quantizedStep(for: rawBrightness)))) / Float(totalBrightnessSteps)
    }
}

private typealias DisplayServicesGetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias DisplayServicesSetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
