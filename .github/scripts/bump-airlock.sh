#!/bin/bash
# Moves Casks/airlock.rb to the newest Airlock release in the appcast, but only
# after the download proves it is the real build: the size the appcast states,
# notarized by Apple, signed by Airlock's Developer ID team, and carrying the
# bundle ID and version the appcast claims. Anything else fails the run and
# leaves the cask alone.
#
# Safe to run by hand: `.github/scripts/bump-airlock.sh` from the tap's root.
# Needs macOS (spctl, codesign, hdiutil). Written for the stock bash 3.2.

set -euo pipefail

APPCAST_URL="https://useairlock.app/appcast.xml"
DOWNLOAD_PREFIX="https://useairlock.app/downloads/Airlock-"
TEAM_ID="X77R7CFNAY"
BUNDLE_ID="com.airlock.app"
CASK="${CASK:-Casks/airlock.rb}"

fail() {
  echo "error: $*" >&2
  exit 1
}

# Both helpers capture a tool's whole output before matching it. Piping straight
# into `grep -q` lets grep exit at the first match, the tool then dies of
# SIGPIPE, and pipefail reports a correctly signed build as a failure.
team_of() {
  local out
  out="$(codesign -dv "$1" 2>&1)" || return 0
  printf '%s\n' "$out" | sed -n 's/^TeamIdentifier=//p'
}

notarized() { # notarized open|execute PATH
  local out
  if [ "$1" = open ]; then
    out="$(spctl --assess --type open --context context:primary-signature -vv "$2" 2>&1)" || return 1
  else
    out="$(spctl --assess --type execute -vv "$2" 2>&1)" || return 1
  fi
  case "$out" in
    *"source=Notarized Developer ID"*) return 0 ;;
  esac
  return 1
}

work="$(mktemp -d)"
mnt="$work/mnt"
cleanup() {
  if [ -d "$mnt" ]; then
    hdiutil detach "$mnt" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

[ -f "$CASK" ] || fail "no cask at $CASK"
current="$(sed -n 's/^  version "\(.*\)"$/\1/p' "$CASK")"
[ -n "$current" ] || fail "could not read the version from $CASK"

curl -fsSL --retry 3 "$APPCAST_URL" -o "$work/appcast.xml"

# Newest stable item: the highest build number among items with no channel.
# A beta channel, if one is ever added, never reaches the cask.
count="$(xmllint --xpath 'count(//item)' "$work/appcast.xml")"
best_build=-1
best=""
i=1
while [ "$i" -le "$count" ]; do
  item="(//item)[$i]"
  channel="$(xmllint --xpath "string($item/*[local-name()='channel'])" "$work/appcast.xml")"
  build="$(xmllint --xpath "string($item/*[local-name()='version'])" "$work/appcast.xml")"
  if [ -z "$channel" ] && [[ "$build" =~ ^[0-9]+$ ]] && [ "$build" -gt "$best_build" ]; then
    best_build="$build"
    best="$item"
  fi
  i=$((i + 1))
done
[ -n "$best" ] || fail "no stable release in the appcast"

latest="$(xmllint --xpath "string($best/*[local-name()='shortVersionString'])" "$work/appcast.xml")"
url="$(xmllint --xpath "string($best/enclosure/@url)" "$work/appcast.xml")"
length="$(xmllint --xpath "string($best/enclosure/@length)" "$work/appcast.xml")"

# The version ends up in a commit message and a file; allow digits and dots only.
[[ "$latest" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || fail "unexpected version '$latest'"
[[ "$length" =~ ^[0-9]+$ ]] || fail "unexpected length '$length'"

if [ "$latest" = "$current" ]; then
  echo "Up to date: $current"
  exit 0
fi
newest="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)"
[ "$newest" = "$latest" ] || fail "appcast offers $latest, older than the cask's $current"

# The cask builds its URL from the version, so the appcast must point at exactly
# that file, or the checksum below would describe a different download.
[ "$url" = "${DOWNLOAD_PREFIX}${latest}.dmg" ] || fail "appcast URL $url is not ${DOWNLOAD_PREFIX}${latest}.dmg"

dmg="$work/Airlock-$latest.dmg"
curl -fsSL --retry 3 "$url" -o "$dmg"
size="$(stat -f %z "$dmg")"
[ "$size" = "$length" ] || fail "downloaded $size bytes, appcast says $length"

# The disk image: notarized, and signed by our team.
notarized open "$dmg" || fail "the disk image is not notarized"
[ "$(team_of "$dmg")" = "$TEAM_ID" ] || fail "the disk image is not signed by $TEAM_ID"

# The app inside it: same checks, plus the identity and version it claims.
mkdir -p "$mnt"
hdiutil attach "$dmg" -nobrowse -readonly -noautoopen -mountpoint "$mnt" -quiet
app="$mnt/Airlock.app"
[ -d "$app" ] || fail "no Airlock.app in the disk image"
codesign --verify --deep --strict "$app" || fail "Airlock.app's signature does not verify"
notarized execute "$app" || fail "Airlock.app is not notarized"
[ "$(team_of "$app")" = "$TEAM_ID" ] || fail "Airlock.app is not signed by $TEAM_ID"
plist="$app/Contents/Info.plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = "$BUNDLE_ID" ] \
  || fail "unexpected bundle ID"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" = "$latest" ] \
  || fail "the app inside says a different version than $latest"
hdiutil detach "$mnt" -quiet
rmdir "$mnt"

sha="$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)"
sed -i '' \
  -e "s/^  version \".*\"$/  version \"$latest\"/" \
  -e "s/^  sha256 \".*\"$/  sha256 \"$sha\"/" \
  "$CASK"

echo "Updated $CASK: $current -> $latest ($sha)"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=$latest" >> "$GITHUB_OUTPUT"
fi
