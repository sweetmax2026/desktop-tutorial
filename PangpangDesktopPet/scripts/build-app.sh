#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
app_dir="${project_dir}/build/pangpang.app"
contents_dir="${app_dir}/Contents"
iconset_dir="${project_dir}/build/pangpang.iconset"
asset_catalog_dir="${project_dir}/build/Assets.xcassets"
asset_info_plist="${project_dir}/build/AppIcon-info.plist"

rm -rf "${app_dir}"
rm -rf "${iconset_dir}"
rm -rf "${asset_catalog_dir}"
rm -f "${asset_info_plist}"
mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources" "${iconset_dir}" "${asset_catalog_dir}/AppIcon.appiconset"

xcrun swiftc -parse-as-library -framework AppKit -framework SwiftUI -framework UserNotifications -o "${contents_dir}/MacOS/PangpangDesktopPet" "${project_dir}"/*.swift
cp "${project_dir}/Info.plist" "${contents_dir}/Info.plist"
cp "${project_dir}/Resources/pangpang.png" "${contents_dir}/Resources/pangpang.png"

# macOS notifications use the app bundle icon. Package pangpang's current
# light-blue circular mark as a multi-resolution .icns asset.
xcrun swift "${script_dir}/make-app-icon.swift" "${project_dir}/Resources/pangpang.png" "${iconset_dir}/icon_512x512@2x.png" 1024
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png"; do
  side="${spec%% *}"
  name="${spec#* }"
  sips -z "${side}" "${side}" "${iconset_dir}/icon_512x512@2x.png" --out "${iconset_dir}/${name}" >/dev/null
done
iconutil -c icns "${iconset_dir}" -o "${contents_dir}/Resources/pangpang.icns"
cp "${project_dir}/Assets.xcassets/Contents.json" "${asset_catalog_dir}/Contents.json"
cp "${project_dir}/Assets.xcassets/AppIcon.appiconset/Contents.json" "${asset_catalog_dir}/AppIcon.appiconset/Contents.json"
cp "${iconset_dir}"/*.png "${asset_catalog_dir}/AppIcon.appiconset/"
xcrun actool "${asset_catalog_dir}" --compile "${contents_dir}/Resources" --platform macosx --minimum-deployment-target 13.0 --app-icon AppIcon --output-partial-info-plist "${asset_info_plist}" >/dev/null
plutil -replace CFBundleIconFile -string AppIcon "${contents_dir}/Info.plist"
codesign --force --sign - "${app_dir}"
echo "Built ${app_dir}"
