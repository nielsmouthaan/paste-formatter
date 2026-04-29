#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Paste Formatter"
EXECUTABLE_TARGET="PasteFormatter"
EXECUTABLE_NAME="Paste Formatter"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_TEMPLATE="$ROOT_DIR/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ENTITLEMENTS_PATH="$ROOT_DIR/PasteFormatter.entitlements"
PRIVACY_MANIFEST="$ROOT_DIR/PrivacyInfo.xcprivacy"
ICON_NAME="AppIcon"
ICON_SOURCE_PATH="$ROOT_DIR/Assets/$ICON_NAME.png"
MENU_BAR_ICON_SOURCE_PATH="$ROOT_DIR/Assets/MenuBarIcon.png"
NOTARIZATION_ZIP="$DIST_DIR/$APP_NAME-notarization.zip"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_TEMPLATE")"
RELEASE_ZIP="$DIST_DIR/$APP_NAME $MARKETING_VERSION.zip"
APP_STORE_PACKAGE="$DIST_DIR/PasteFormatter-$MARKETING_VERSION-mas.pkg"

usage() {
  cat <<'EOF'
Build a macOS Paste Formatter app bundle in dist/, optionally sign it,
notarize it, create a zipped release build, or create a Mac App Store
installer package.

Usage:
  ./scripts/build-app.sh --bundle-identifier <identifier> [options]
  ./scripts/build-app.sh --help

Options:
  --bundle-identifier        Required bundle identifier for the generated app bundle.
  --signing-identity         Optional code signing identity to sign the app bundle.
  --entitlements             Entitlements plist used for code signing.
                             Defaults to PasteFormatter.entitlements.
  --provisioning-profile     Provisioning profile to embed before signing.
                             Required with --app-store-package.
  --notarize                 Submit the signed app to Apple notarization and staple the ticket.
  --release-zip              Create a distributable zip in dist/ after building.
  --app-store-package        Create a Mac App Store installer package in dist/.
  --installer-signing-identity
                             Required with --app-store-package. Use a Mac Installer
                             Distribution identity, commonly named
                             "3rd Party Mac Developer Installer: ...".
  --help                     Show this help text.

Examples:
  ./scripts/build-app.sh --bundle-identifier com.example.paste-formatter

  ./scripts/build-app.sh \
    --bundle-identifier com.example.paste-formatter \
    --signing-identity "Developer ID Application: Example (TEAMID)" \
    --notarize \
    --release-zip

  ./scripts/build-app.sh \
    --bundle-identifier com.example.paste-formatter \
    --signing-identity "3rd Party Mac Developer Application: Example (TEAMID)" \
    --installer-signing-identity "3rd Party Mac Developer Installer: Example (TEAMID)" \
    --provisioning-profile "Paste Formatter.provisionprofile" \
    --app-store-package
EOF
}

BUNDLE_IDENTIFIER=""
SIGNING_IDENTITY=""
INSTALLER_SIGNING_IDENTITY=""
PROVISIONING_PROFILE=""
NOTARIZE=false
CREATE_RELEASE_ZIP=false
CREATE_APP_STORE_PACKAGE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundle-identifier)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --bundle-identifier" >&2
        usage >&2
        exit 1
      fi
      BUNDLE_IDENTIFIER="$2"
      shift 2
      ;;
    --signing-identity)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --signing-identity" >&2
        usage >&2
        exit 1
      fi
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --entitlements)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --entitlements" >&2
        usage >&2
        exit 1
      fi
      ENTITLEMENTS_PATH="$2"
      shift 2
      ;;
    --installer-signing-identity)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --installer-signing-identity" >&2
        usage >&2
        exit 1
      fi
      INSTALLER_SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --provisioning-profile)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --provisioning-profile" >&2
        usage >&2
        exit 1
      fi
      PROVISIONING_PROFILE="$2"
      shift 2
      ;;
    --notarize)
      NOTARIZE=true
      shift
      ;;
    --release-zip)
      CREATE_RELEASE_ZIP=true
      shift
      ;;
    --app-store-package)
      CREATE_APP_STORE_PACKAGE=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$BUNDLE_IDENTIFIER" ]; then
  echo "Missing required --bundle-identifier argument" >&2
  usage >&2
  exit 1
fi

if [ "$NOTARIZE" = true ] && [ -z "$SIGNING_IDENTITY" ]; then
  echo "Missing required --signing-identity argument for --notarize" >&2
  usage >&2
  exit 1
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Missing required --signing-identity argument for --app-store-package" >&2
    usage >&2
    exit 1
  fi

  if [ -z "$INSTALLER_SIGNING_IDENTITY" ]; then
    echo "Missing required --installer-signing-identity argument for --app-store-package" >&2
    usage >&2
    exit 1
  fi

  if [ -z "$PROVISIONING_PROFILE" ]; then
    echo "Missing required --provisioning-profile argument for --app-store-package" >&2
    usage >&2
    exit 1
  fi

  if [ "$NOTARIZE" = true ]; then
    echo "--notarize is for Developer ID distribution and cannot be combined with --app-store-package" >&2
    exit 1
  fi

  if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "Missing entitlements file for --app-store-package: $ENTITLEMENTS_PATH" >&2
    exit 1
  fi
fi

if [ -n "$PROVISIONING_PROFILE" ] && [ ! -f "$PROVISIONING_PROFILE" ]; then
  echo "Provisioning profile not found: $PROVISIONING_PROFILE" >&2
  exit 1
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  PROFILE_PLIST="$(mktemp "${TMPDIR:-/tmp}/paste-formatter-profile.XXXXXX.plist")"
  if ! /usr/bin/openssl smime -inform der -verify -noverify -in "$PROVISIONING_PROFILE" -out "$PROFILE_PLIST" >/dev/null 2>&1; then
    rm -f "$PROFILE_PLIST"
    echo "Could not decode provisioning profile: $PROVISIONING_PROFILE" >&2
    exit 1
  fi

  PROFILE_APP_IDENTIFIER="$(
    /usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" "$PROFILE_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$PROFILE_PLIST" 2>/dev/null \
      || true
  )"
  rm -f "$PROFILE_PLIST"

  PROFILE_BUNDLE_IDENTIFIER="${PROFILE_APP_IDENTIFIER#*.}"
  if [ -z "$PROFILE_APP_IDENTIFIER" ] || [ "$PROFILE_BUNDLE_IDENTIFIER" != "$BUNDLE_IDENTIFIER" ]; then
    echo "Provisioning profile does not match bundle identifier $BUNDLE_IDENTIFIER." >&2
    echo "Profile application identifier: ${PROFILE_APP_IDENTIFIER:-unknown}" >&2
    exit 1
  fi
fi

echo "Building release executable..."
if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  xcodebuildmcp swift-package build \
    --package-path "$ROOT_DIR" \
    --configuration release \
    --architectures arm64 x86_64
else
  xcodebuildmcp swift-package build --package-path "$ROOT_DIR" --configuration release
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  EXECUTABLE_PATH="$ROOT_DIR/.build/apple/Products/Release/$EXECUTABLE_TARGET"
else
  EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$EXECUTABLE_TARGET" -type f ! -path "$ROOT_DIR/.build/apple/*" | head -n 1)"
fi

if [ -z "$EXECUTABLE_PATH" ] || [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "Expected release executable not found under $ROOT_DIR/.build" >&2
  exit 1
fi

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"

sed \
  -e "s/__BUNDLE_IDENTIFIER__/$BUNDLE_IDENTIFIER/g" \
  "$INFO_TEMPLATE" > "$INFO_PLIST"

if [ ! -f "$ICON_SOURCE_PATH" ]; then
  echo "Missing app icon: $ICON_SOURCE_PATH" >&2
  exit 1
fi

ICON_WIDTH="$(/usr/bin/sips -g pixelWidth "$ICON_SOURCE_PATH" | awk '/pixelWidth/ { print $2 }')"
ICON_HEIGHT="$(/usr/bin/sips -g pixelHeight "$ICON_SOURCE_PATH" | awk '/pixelHeight/ { print $2 }')"

if [ "$ICON_WIDTH" != "1024" ] || [ "$ICON_HEIGHT" != "1024" ]; then
  echo "App icon must be a 1024x1024 PNG: $ICON_SOURCE_PATH is ${ICON_WIDTH}x${ICON_HEIGHT}" >&2
  exit 1
fi

ICON_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/paste-formatter-icon.XXXXXX")"
ICONSET_DIR="$ICON_WORK_DIR/$ICON_NAME.iconset"
mkdir -p "$ICONSET_DIR"

/usr/bin/sips -z 16 16 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
/usr/bin/sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
/usr/bin/sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
/usr/bin/sips -z 64 64 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
/usr/bin/sips -z 128 128 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
/usr/bin/sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
/usr/bin/sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
/usr/bin/sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
/usr/bin/sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE_PATH" "$ICONSET_DIR/icon_512x512@2x.png"

/usr/bin/iconutil --convert icns --output "$RESOURCES_DIR/$ICON_NAME.icns" "$ICONSET_DIR"
rm -rf "$ICON_WORK_DIR"

if [ ! -f "$MENU_BAR_ICON_SOURCE_PATH" ]; then
  echo "Missing menu bar icon: $MENU_BAR_ICON_SOURCE_PATH" >&2
  exit 1
fi

MENU_BAR_ICON_WIDTH="$(/usr/bin/sips -g pixelWidth "$MENU_BAR_ICON_SOURCE_PATH" | awk '/pixelWidth/ { print $2 }')"
MENU_BAR_ICON_HEIGHT="$(/usr/bin/sips -g pixelHeight "$MENU_BAR_ICON_SOURCE_PATH" | awk '/pixelHeight/ { print $2 }')"

if [ "$MENU_BAR_ICON_WIDTH" != "36" ] || [ "$MENU_BAR_ICON_HEIGHT" != "36" ]; then
  echo "Menu bar icon must be a 36x36 PNG: $MENU_BAR_ICON_SOURCE_PATH is ${MENU_BAR_ICON_WIDTH}x${MENU_BAR_ICON_HEIGHT}" >&2
  exit 1
fi

cp "$MENU_BAR_ICON_SOURCE_PATH" "$RESOURCES_DIR/MenuBarIcon.png"

if [ -f "$PRIVACY_MANIFEST" ]; then
  cp "$PRIVACY_MANIFEST" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
fi

while IFS= read -r RESOURCE_BUNDLE; do
  echo "Copying resources from $(basename "$RESOURCE_BUNDLE")..."
  find "$RESOURCE_BUNDLE" -maxdepth 1 -type f -exec cp {} "$RESOURCES_DIR/" \;
done < <(find "$(dirname "$EXECUTABLE_PATH")" -maxdepth 1 -name "*.bundle" -type d)

if [ -n "$PROVISIONING_PROFILE" ]; then
  cp "$PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
fi

chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  BINARY_ARCHITECTURES="$(/usr/bin/lipo -archs "$MACOS_DIR/$EXECUTABLE_NAME")"
  if [[ " $BINARY_ARCHITECTURES " != *" arm64 "* ]] || [[ " $BINARY_ARCHITECTURES " != *" x86_64 "* ]]; then
    echo "Mac App Store package builds must include arm64 and x86_64. Found: $BINARY_ARCHITECTURES" >&2
    exit 1
  fi

  echo "Verified universal app binary architectures: $BINARY_ARCHITECTURES"
fi

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "Signing app bundle with $SIGNING_IDENTITY..."
  CODESIGN_ARGS=(--force --sign "$SIGNING_IDENTITY")

  if [ -f "$ENTITLEMENTS_PATH" ]; then
    CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS_PATH")
  fi

  if [ "$CREATE_APP_STORE_PACKAGE" = false ]; then
    CODESIGN_ARGS+=(--options runtime --timestamp)
  fi

  /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
else
  echo "Skipping code signing. Pass --signing-identity to sign the app bundle."
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  echo "Creating Mac App Store package at $APP_STORE_PACKAGE..."
  rm -f "$APP_STORE_PACKAGE"
  productbuild \
    --sign "$INSTALLER_SIGNING_IDENTITY" \
    --component "$APP_BUNDLE" /Applications \
    "$APP_STORE_PACKAGE"
fi

if [ "$NOTARIZE" = true ]; then
  if ! command -v asc >/dev/null 2>&1; then
    echo "The asc CLI is required for notarization. Install and authenticate asc before using --notarize." >&2
    exit 1
  fi

  echo "Creating notarization zip at $NOTARIZATION_ZIP..."
  rm -f "$NOTARIZATION_ZIP"
  ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZATION_ZIP"

  echo "Submitting app for notarization..."
  asc notarization submit --file "$NOTARIZATION_ZIP" --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose "$APP_BUNDLE"

  rm -f "$NOTARIZATION_ZIP"
fi

if [ "$CREATE_RELEASE_ZIP" = true ]; then
  echo "Creating release zip at $RELEASE_ZIP..."
  rm -f "$RELEASE_ZIP"
  ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_ZIP"
fi

echo "App bundle created:"
echo "$APP_BUNDLE"

if [ "$CREATE_RELEASE_ZIP" = true ]; then
  echo "Release zip created:"
  echo "$RELEASE_ZIP"
fi

if [ "$CREATE_APP_STORE_PACKAGE" = true ]; then
  echo "Mac App Store package created:"
  echo "$APP_STORE_PACKAGE"
fi
