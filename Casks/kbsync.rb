cask "kbsync" do
  version "0.2.0"
  sha256 "b295d2959bf1649ae675a9a1d132d9f3201bd3bbe7aa9d5ad985df40e8dad4e7"

  url "https://github.com/simar-s2/kbsync/releases/download/v#{version}/kbsync-#{version}.zip"
  name "kbsync"
  desc "Menu bar app that makes the keyboard backlight follow the screen brightness"
  homepage "https://github.com/simar-s2/kbsync"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "kbsync.app"

  zap trash: "~/Library/Preferences/com.github.simar-s2.kbsync.menubar.plist"

  caveats <<~EOS
    kbsync isn't signed with a paid Apple Developer ID, so macOS blocks the
    first launch. Open kbsync once, then go to System Settings > Privacy &
    Security and click "Open Anyway".
  EOS
end
