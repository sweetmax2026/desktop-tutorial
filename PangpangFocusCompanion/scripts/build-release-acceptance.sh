#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
contents="${project_dir}/build/Pang Release Acceptance.app/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources"
xcrun swiftc -parse-as-library -D RELEASE_ACCEPTANCE -target "$(uname -m)-apple-macos13.0" \
  -module-cache-path "$project_dir/build/ModuleCache" -framework AppKit -framework SwiftUI \
  -framework UserNotifications -framework Carbon "$project_dir"/*.swift \
  "$project_dir/tests/ReleaseAcceptanceApp.swift" "$project_dir/tests/AcceptanceLifecycleRecorder.swift" -o "$contents/MacOS/ReleaseAcceptance"
cp "$project_dir/Info.plist" "$contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.tiantian.pangpang.release-acceptance' "$contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable ReleaseAcceptance' "$contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Pang Release Acceptance' "$contents/Info.plist"
# Acceptance never sends online feedback by accident.
/usr/libexec/PlistBuddy -c 'Set :PangFeedbackURL ' "$contents/Info.plist"
cp "$project_dir"/Resources/*.png "$contents/Resources/"
cp "$project_dir/Resources/PrivacyPolicy.txt" "$project_dir/Resources/PrivacyInfo.xcprivacy" "$contents/Resources/"
codesign --force --sign - "${contents:h}"
codesign --verify --deep --strict "${contents:h}"
echo "Built isolated release acceptance host: ${contents:h}"
