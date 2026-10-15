#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
app_dir="${project_dir}/build/Pang 大师.app"
developer_dir="$(xcode-select -p)"
compiler="${developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "${project_dir}/build"
staging_dir="$(mktemp -d "${project_dir}/build/staging-XXXXXX")"
staging_app="${staging_dir}/Pang 大师.app"
contents_dir="${staging_app}/Contents"
mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources"

# Compile the native Icon Composer document for Mac explicitly. The target-device
# flag is essential: without it actool can report success but emit no icon assets.
"${compiler}" -parse-as-library -O -module-cache-path "${project_dir}/build/ModuleCache" -sdk "${sdk}" -target "$(uname -m)-apple-macos13.0" -framework AppKit -framework SwiftUI -framework UserNotifications -framework Carbon -o "${contents_dir}/MacOS/PangpangDesktopPet" "${project_dir}"/*.swift
cp "${project_dir}/Info.plist" "${contents_dir}/Info.plist"
cp "${project_dir}/Resources/pangpang.png" "${contents_dir}/Resources/pangpang.png"
cp "${project_dir}/Resources/pangpang-head-v1.png" "${contents_dir}/Resources/pangpang-head-v1.png"
cp "${project_dir}"/Resources/pangpang-guard-tilt-v1.png "${contents_dir}/Resources/"
cp "${project_dir}"/Resources/pangpang-home-peek-v1.png "${contents_dir}/Resources/"
cp "${project_dir}/Resources/focus-paw-stamp.png" "${contents_dir}/Resources/focus-paw-stamp.png"
cp "${project_dir}/Resources/focus-paw-blue.png" "${contents_dir}/Resources/focus-paw-blue.png"
cp "${project_dir}/Resources/focus-paw-simple-v1.png" "${contents_dir}/Resources/"
cp "${project_dir}/Resources/pangpang-rest-peek-v1.png" "${contents_dir}/Resources/"
cp "${project_dir}/Resources/focus-quiet-backdrop-v1.png" "${contents_dir}/Resources/"
cp "${project_dir}"/Resources/mood-*.png "${contents_dir}/Resources/"
"${developer_dir}/usr/bin/actool" "${project_dir}/Resources/Pangpang.icon" --compile "${contents_dir}/Resources" --platform macosx --minimum-deployment-target 13.0 --target-device mac --app-icon Pangpang --output-partial-info-plist "${staging_dir}/icon-info.plist" >/dev/null
test -s "${contents_dir}/Resources/Pangpang.icns"
test -s "${contents_dir}/Resources/Assets.car"
codesign --force --sign - "${staging_app}"
codesign --verify --deep --strict "${staging_app}"
rm -rf "${app_dir}"
mv "${staging_app}" "${app_dir}"
echo "Built ${app_dir}"
