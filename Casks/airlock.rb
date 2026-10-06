cask "airlock" do
  version "1.0.16"
  sha256 "23a133490b1ad2b4bdd067492b261acf5e43a72b7d7dbcf64fe68c027b25a52a"

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
