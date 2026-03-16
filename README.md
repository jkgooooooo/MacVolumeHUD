# MacVolumeHUD

MacVolumeHUD is a small macOS utility that replaces the newer corner-style volume popover with a centered HUD inspired by older versions of macOS.

## Why I Made This

After updating to macOS Tahoe, the volume UI changed at some point and started showing up as a small indicator in the top-right corner. I kept missing it.

I preferred the older Apple volume HUD that appeared in the middle of the screen and was immediately readable, so I built this app to bring that style back.

## What The App Does

- Captures volume up, volume down, and mute key input
- Shows a custom centered volume HUD
- Keeps the HUD style closer to the older macOS look
- Lets you choose between `Small`, `Medium`, and `Large`
- The original macOS fine adjustment behavior with `Option` + `Shift` still works here as well

## Setup

MacVolumeHUD needs Accessibility permission so it can intercept media keys and replace the default system HUD behavior.

1. Run the app from Xcode
2. Grant Accessibility access when prompted
3. Return to the app
4. Use your keyboard volume keys normally

If you enable permission while the app is already open, coming back to the app should refresh interception automatically.

## Notes

- If the default macOS volume UI still appears, check that Accessibility access is enabled for `MacVolumeHUD`
- If needed, quit and reopen the app once after changing permission settings
- HUD size changes can be tested directly from the settings window

## Build

This project is a native macOS app built with SwiftUI and AppKit.

1. Open [MacVolumeHUD.xcodeproj](/Users/ko/Desktop/SoundBar/MacVolumeHUD.xcodeproj)
2. Select the `MacVolumeHUD` scheme
3. Build and run

Main files:

- [MacVolumeHUDApp.swift](/Users/ko/Desktop/SoundBar/MacVolumeHUD/MacVolumeHUDApp.swift)
- [VolumeManager.swift](/Users/ko/Desktop/SoundBar/MacVolumeHUD/VolumeManager.swift)
- [MediaKeyInterceptor.swift](/Users/ko/Desktop/SoundBar/MacVolumeHUD/MediaKeyInterceptor.swift)
- [HUDWindowManager.swift](/Users/ko/Desktop/SoundBar/MacVolumeHUD/HUDWindowManager.swift)
- [RetroHUDView.swift](/Users/ko/Desktop/SoundBar/MacVolumeHUD/RetroHUDView.swift)
