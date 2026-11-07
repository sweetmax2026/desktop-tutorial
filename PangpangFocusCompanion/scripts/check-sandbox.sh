#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
developer_dir="$(xcode-select -p)"
compiler="${developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
run_dir="$(mktemp -d "${project_dir}/build/sandbox-check-XXXXXX")"
fixture="${run_dir}/Sandbox Fixture.app"
probe="${run_dir}/Sandbox Probe.app"
for target in "$fixture" "$probe"; do mkdir -p "$target/Contents/MacOS"; done
common=(-parse-as-library -sdk "$sdk" -target "$(uname -m)-apple-macos13.0" -module-cache-path "${project_dir}/build/ModuleCache")
"$compiler" "${common[@]}" -framework AppKit "${project_dir}/tests/SandboxFixture.swift" -o "$fixture/Contents/MacOS/Fixture"
"$compiler" "${common[@]}" -framework AppKit -framework Carbon -framework Security \
  "${project_dir}/DailyCount.swift" "${project_dir}/PomodoroStore.swift" "${project_dir}/AppBlockerStore.swift" \
  "${project_dir}/tests/SandboxProbe.swift" -o "$probe/Contents/MacOS/Probe"
probe_id="com.tiantian.pangpang.sandbox-probe.$(uuidgen | tr '[:upper:]' '[:lower:]')"
python3 - "$fixture" "$probe" "$probe_id" <<'PY'
import plistlib,sys
for path,exe,bundle in [(sys.argv[1],"Fixture","com.tiantian.pangpang.sandbox-fixture"),(sys.argv[2],"Probe",sys.argv[3])]:
    with open(path+"/Contents/Info.plist","wb") as f:
        plistlib.dump(dict(CFBundleExecutable=exe,CFBundleIdentifier=bundle,CFBundleName=exe,CFBundlePackageType="APPL",LSUIElement=exe=="Probe"),f)
PY
codesign --force --sign - "$fixture"
codesign --force --sign - --entitlements "${project_dir}/PangpangSandbox.entitlements" "$probe"
codesign --verify --deep --strict "$probe"
canary=/private/tmp/pang-sandbox-denial-canary
test ! -e "$canary"
print 'test-only sandbox denial canary' > "$canary"
trap 'rm -f "$canary"' EXIT
open -n "$fixture"
open -n -W --stdout "${run_dir}/runtime.log" --stderr "${run_dir}/runtime-errors.log" "$probe"
cat "${run_dir}/runtime.log"
rg -q '^RESULT: PASS$' "${run_dir}/runtime.log"
open -n -W --stdout "${run_dir}/relaunch.log" --stderr "${run_dir}/relaunch-errors.log" "$probe" --args --persistence-only
cat "${run_dir}/relaunch.log"
rg -q '^RESULT: PASS$' "${run_dir}/relaunch.log"
echo "Sandbox runtime evidence: ${run_dir}"
