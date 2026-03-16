cask "macvolumehud" do
  version :latest
  sha256 :no_check

  url "https://github.com/YOUR_GITHUB_USERNAME/MacVolumeHUD/releases/latest/download/MacVolumeHUD.zip"
  name "MacVolumeHUD"
  desc "Restores the classic centered macOS volume HUD"
  homepage "https://github.com/YOUR_GITHUB_USERNAME/MacVolumeHUD"

  auto_updates true

  app "MacVolumeHUD.app"

  zap trash: [
    "~/Library/Preferences/ko.MacVolumeHUD.plist",
    "~/Library/Saved Application State/ko.MacVolumeHUD.savedState",
  ]
end
