cask "airlock" do
  version "1.0.9"
  sha256 "bd3c6cc4c5141217668b358e4c2103161dd0429119d39dede0be6eda0689483d"

  url "https://useairlock.app/downloads/Airlock-#{version}.dmg"
  name "Airlock"
  desc "Notch utility with clipboard history, a file shelf and coding-agent approvals"
  homepage "https://useairlock.app/"

  livecheck do
    url "https://useairlock.app/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Airlock.app"

  uninstall quit: "com.airlock.app"

  # Never removed, because they belong to the user: ~/Airlock (the shelf and
  # the agent workspace) and ~/.airlock (approval rules, and the hook that
  # Claude Code and Codex call, which fails open once the app is gone).
  # The Application Support glob skips dotfiles, which keeps the hidden trial
  # record, so a zap and reinstall does not restart the free trial.
  zap trash: [
    "~/Library/Application Support/Airlock/*",
    "~/Library/Caches/com.airlock.app",
    "~/Library/Caches/com.airlock.app.sparkle",
    "~/Library/HTTPStorages/com.airlock.app",
    "~/Library/Preferences/com.airlock.app.plist",
    "~/Library/Saved Application State/com.airlock.app.savedState",
  ]
end
