#!/bin/bash
# Compatibility build for the original DNSCloak Go wrapper.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT
export PATH="$(go env GOPATH)/bin:$PATH"
MOBILE_COMMIT=43a0384520996c8376bfb8637390f12b44773e65
go install golang.org/x/mobile/cmd/gomobile@"$MOBILE_COMMIT"
go install golang.org/x/mobile/cmd/gobind@"$MOBILE_COMMIT"
gomobile init
git clone --branch ios --single-branch https://github.com/s-s/dnscrypt-proxy.git "$BUILD_ROOT/proxy"
git -C "$BUILD_ROOT/proxy" checkout 5b0b3e1c5240098b0b33ea7f453d1313f83371f4
export PROJECT_ROOT BUILD_ROOT
python3 <<'PY'
from pathlib import Path
import os,re,shutil
root=Path(os.environ['BUILD_ROOT'])/'proxy';pkg=root/'dnscrypt-proxy'
version=re.search(r'AppVersion\s*=\s*"([^"]+)"',(pkg/'main.go').read_text()).group(1)
for f in pkg.glob('*.go'):
    if f.name=='main.go' or f.name.endswith(('_linux.go','_windows.go')) or f.name.startswith('privilege'):
        f.unlink();continue
    f.write_text(f.read_text().replace('package main','package dnscrypt').replace('AppVersion','""').replace('proxy.dropPrivilege','//proxy.dropPrivilege'))
shutil.rmtree(root/'vendor',ignore_errors=True)
f=root/'go.mod';f.write_text(f.read_text().replace('module github.com/DNSCrypt/dnscrypt-proxy','module github.com/jedisct1/dnscrypt-proxy'))
shutil.copytree(Path(os.environ['PROJECT_ROOT'])/'framework',pkg,dirs_exist_ok=True)
(pkg/'ios/version.go').write_text('package dnscryptproxy\nconst AppVersion = "'+version+'"\n')
PY
cd "$BUILD_ROOT/proxy/dnscrypt-proxy/ios"
go mod edit -require=github.com/korovkin/limiter@v0.0.0-20190919045942-dac5a6b2a536
go get golang.org/x/mobile@"$MOBILE_COMMIT"
go mod tidy
gomobile bind -target=ios/arm64 -iosversion=12.0 -o "$BUILD_ROOT/Dnscryptproxy.xcframework" .
FRAMEWORK="$(find "$BUILD_ROOT/Dnscryptproxy.xcframework" -path '*ios-arm64/Dnscryptproxy.framework' -type d -print -quit)"
test -n "$FRAMEWORK"
rm -rf "$PROJECT_ROOT/platforms/ios/Dnscryptproxy.framework"
cp -R "$FRAMEWORK" "$PROJECT_ROOT/platforms/ios/Dnscryptproxy.framework"
