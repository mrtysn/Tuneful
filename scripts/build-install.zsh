#!/bin/zsh
# DESC: Build this Tuneful fork, sign it with a stable local identity, install and relaunch
set -euo pipefail

usage() {
  cat <<'EOF'
Build, sign, install and relaunch Tuneful from this checkout.

  scripts/build-install.zsh [--no-launch] [--help]

The signing identity is CODESIGN_IDENTITY (default "Local Dev Signing"): a stable
certificate keeps macOS's grants for the app across rebuilds, which an ad-hoc
signature does not. INSTALL_DIR defaults to /Applications. Needs full Xcode.
EOF
}

do_launch=1
for arg in "$@"; do
  case "$arg" in
    --no-launch) do_launch=0 ;;
    --help|-h)   usage; exit 0 ;;
    *) print -u2 "unknown option: $arg"; usage; exit 2 ;;
  esac
done

REPO_ROOT="${0:A:h:h}"
APP_NAME="Tuneful"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-Local Dev Signing}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

if ! security find-identity -v -p codesigning | grep -qF "$CODESIGN_IDENTITY"; then
  print -u2 "no codesigning identity '$CODESIGN_IDENTITY' in the keychain (security find-identity -v -p codesigning)"
  exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p 2>/dev/null)" != *Xcode* ]]; then
  [[ -d /Applications/Xcode.app/Contents/Developer ]] || { print -u2 "full Xcode is needed: install it from the App Store"; exit 1; }
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

DERIVED="$REPO_ROOT/.build"
BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

print "building $APP_NAME"
xcodebuild \
  -project "$REPO_ROOT/Tuneful.xcodeproj" \
  -scheme Tuneful \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -skipMacroValidation -skipPackagePluginValidation \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CODESIGN_IDENTITY" \
  build \
  | grep -E "error:|\*\* BUILD" || true

[[ -d "$BUILT_APP" ]] || { print -u2 "build produced no app at $BUILT_APP"; exit 1; }

if pgrep -f "$INSTALLED_APP/Contents/" >/dev/null 2>&1; then
  osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
  sleep 1
fi
rm -rf "$INSTALLED_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"
print "installed: $INSTALLED_APP"

if (( do_launch )); then
  open -g -a "$INSTALLED_APP"
  print "launched"
fi
