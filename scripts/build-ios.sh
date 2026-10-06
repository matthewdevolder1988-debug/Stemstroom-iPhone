#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'Deze build vereist macOS met Xcode 26. Gebruik vanaf Windows de handmatige GitHub Actions-workflow.' >&2
  exit 1
fi

xcode_version="$(xcodebuild -version)"
if [[ ! "$xcode_version" =~ ^Xcode\ 26([.]|$) ]]; then
  printf '%s\n' 'Selecteer Xcode 26 via DEVELOPER_DIR of xcode-select.' >&2
  exit 1
fi

mkdir -p build/logs
{
  printf 'UTC: '
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  if [[ -n "${GITHUB_SHA:-}" ]]; then
    printf 'Commit: %s\n' "$GITHUB_SHA"
  fi
  xcodebuild -version
  swift --version
} > build/build-info.txt

plutil -lint App/Info.plist App/PrivacyInfo.xcprivacy Stemstroom.xcodeproj/project.pbxproj
swift test 2>&1 | tee build/logs/swift-test.log

xcodebuild \
  -project Stemstroom.xcodeproj \
  -scheme Stemstroom \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee build/logs/simulator-build.log

xcodebuild \
  -project Stemstroom.xcodeproj \
  -scheme Stemstroom \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee build/logs/iphone-build.log

app_path="$project_dir/build/DerivedData/Build/Products/Release-iphoneos/Stemstroom.app"
test -x "$app_path/Stemstroom"
plutil -lint "$app_path/Info.plist" "$app_path/PrivacyInfo.xcprivacy"

staging_dir="$(mktemp -d "$project_dir/build/ipa.XXXXXX")"
cleanup() {
  case "$staging_dir" in
    "$project_dir"/build/ipa.*) rm -rf -- "$staging_dir" ;;
    *) printf '%s\n' 'Opruimen geweigerd: onverwachte tijdelijke map.' >&2 ;;
  esac
}
trap cleanup EXIT
mkdir "$staging_dir/Payload"
ditto "$app_path" "$staging_dir/Payload/Stemstroom.app"
ditto -c -k --keepParent "$staging_dir/Payload" "$staging_dir/Stemstroom-unsigned.ipa"
unzip -t "$staging_dir/Stemstroom-unsigned.ipa" > build/logs/ipa-check.log
mv -f "$staging_dir/Stemstroom-unsigned.ipa" build/Stemstroom-unsigned.ipa
shasum -a 256 build/Stemstroom-unsigned.ipa > build/Stemstroom-unsigned.sha256
printf '%s\n' 'Gemaakt: build/Stemstroom-unsigned.ipa. Ondertekening/installatie op een iPhone en de duurtest zijn nog vereist.'
