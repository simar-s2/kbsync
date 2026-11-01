class Kbsync < Formula
  desc "Make the MacBook keyboard backlight follow the screen brightness"
  homepage "https://github.com/simar-s2/kbsync"
  url "https://github.com/simar-s2/kbsync/releases/download/v0.2.1/kbsync-0.2.1-src.tar.gz"
  sha256 "bf58b33a79334f2aae9061c6c08d5041f78ea04ebf47f1c9edf085766614e40a"
  license "MIT"
  head "https://github.com/simar-s2/kbsync.git", branch: "main"

  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "--configuration", "release", "--product", "kbsync"
    bin.install ".build/release/kbsync"
  end

  def caveats
    <<~EOS
      To run kbsync in the background and at login:
        kbsync install
    EOS
  end

  test do
    assert_match "kbsync #{version}", shell_output("#{bin}/kbsync version")
    assert_match "--max", shell_output("#{bin}/kbsync help")
  end
end
