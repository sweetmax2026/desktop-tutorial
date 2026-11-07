#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
developer_dir="$(xcode-select -p)"
contents="${project_dir}/build/cycle-render/Render.app/Contents"
mkdir -p "${contents}/MacOS" "${contents}/Resources"
sources=("${project_dir}"/*.swift)
sources=("${(@)sources:#*/PangpangDesktopPet.swift}")
"${developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" -parse-as-library \
  -sdk "${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" \
  -target "$(uname -m)-apple-macos13.0" -module-cache-path "${project_dir}/build/ModuleCache" \
  -framework AppKit -framework SwiftUI "${sources[@]}" "${project_dir}/tests/AutomaticCycleRender.swift" \
  -o "${contents}/MacOS/Render"
cp "${project_dir}"/Resources/*.png "${contents}/Resources/"
cp "${project_dir}/tests/FlowPreview-Info.plist" "${contents}/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Render' "${contents}/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.tiantian.pangpang.cycle-render' "${contents}/Info.plist"
codesign --force --sign - "${contents:h}"
"${contents}/MacOS/Render" "${project_dir}/design/automatic-cycle-toggle-2026-11-04"
