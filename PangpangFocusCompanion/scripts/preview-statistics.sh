#!/bin/zsh
set -euo pipefail
script_dir="${0:A:h}"
project_dir="${script_dir:h}"
developer_dir="$(xcode-select -p)"
compiler="${developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
preview="${project_dir}/build/Pang Statistics Preview.app/Contents"
mkdir -p "${preview}/MacOS" "${preview}/Resources"
sources=("${project_dir}"/*.swift)
sources=("${(@)sources:#*/PangpangDesktopPet.swift}")
"${compiler}" -parse-as-library -sdk "${sdk}" -target "$(uname -m)-apple-macos13.0" \
  -module-cache-path "${project_dir}/build/ModuleCache" -framework AppKit -framework SwiftUI \
  "${sources[@]}" "${project_dir}/tests/StatisticsSurfacePreview.swift" -o "${preview}/MacOS/StatisticsSurfacePreview"
cp "${project_dir}/tests/StatisticsPreview-Info.plist" "${preview}/Info.plist"
cp "${project_dir}"/Resources/*.png "${preview}/Resources/"
codesign --force --sign - "${preview:h}"
echo "Built ${preview:h}"
