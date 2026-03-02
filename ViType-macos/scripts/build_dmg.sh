#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build_dmg.sh [OPTIONS]

Options:
  --skip-build              Skip xcodebuild, use existing app
  --app /path/to/ViType.app Path to existing app (required with --skip-build)
  --out-dir /path/to/out    Output directory for DMG (default: dist/)
  --volname NAME            DMG volume name (default: ViType)
  --sign                    Enable code signing with Developer ID
  --notarize                Enable notarization (requires --sign)
  --apple-id EMAIL          Apple ID for notarization
  --team-id ID              Apple Developer Team ID (default: WRVJA39U7V)
  --signing-identity NAME   Code signing identity (default: auto-detect)
  -h, --help                Show this help

Environment Variables:
  APPLE_ID_PASSWORD         App-specific password for notarization
                            (or will prompt via Keychain)

Examples:
  # Build without signing (development)
  ./scripts/build_dmg.sh

  # Build with signing (no notarization)
  ./scripts/build_dmg.sh --sign

  # Full release build (like CI)
  ./scripts/build_dmg.sh --sign --notarize --apple-id "you@example.com"

  # Use existing app
  ./scripts/build_dmg.sh --skip-build --app "/path/to/ViType.app" --sign
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_DIR}/.." && pwd)"

SKIP_BUILD="0"
APP_PATH=""
OUT_DIR="${PROJECT_DIR}/dist"
VOLNAME="ViType"
SIGN_APP="0"
NOTARIZE_APP="0"
APPLE_ID=""
TEAM_ID="WRVJA39U7V"
SIGNING_IDENTITY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD="1"
      shift
      ;;
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --volname)
      VOLNAME="${2:-}"
      shift 2
      ;;
    --sign)
      SIGN_APP="1"
      shift
      ;;
    --notarize)
      NOTARIZE_APP="1"
      shift
      ;;
    --apple-id)
      APPLE_ID="${2:-}"
      shift 2
      ;;
    --team-id)
      TEAM_ID="${2:-}"
      shift 2
      ;;
    --signing-identity)
      SIGNING_IDENTITY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found in PATH: $1" >&2
    exit 1
  fi
}

require_cmd hdiutil
require_cmd /usr/bin/ditto
require_cmd /usr/bin/plutil

# Validate signing/notarization options
if [ "${NOTARIZE_APP}" = "1" ] && [ "${SIGN_APP}" != "1" ]; then
  echo "error: --notarize requires --sign" >&2
  exit 2
fi

if [ "${NOTARIZE_APP}" = "1" ] && [ -z "${APPLE_ID}" ]; then
  echo "error: --notarize requires --apple-id" >&2
  exit 2
fi

if [ "${SIGN_APP}" = "1" ]; then
  require_cmd codesign

  # Auto-detect signing identity if not provided
  if [ -z "${SIGNING_IDENTITY}" ]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
    if [ -z "${SIGNING_IDENTITY}" ]; then
      echo "error: No 'Developer ID Application' certificate found in Keychain." >&2
      echo "       Install your certificate or specify --signing-identity" >&2
      exit 1
    fi
    echo "Using signing identity: ${SIGNING_IDENTITY}"
  fi
fi

if [ "${NOTARIZE_APP}" = "1" ]; then
  require_cmd xcrun
fi

if [ "${SKIP_BUILD}" != "1" ]; then
  require_cmd xcodebuild

  DERIVED_DATA="${PROJECT_DIR}/.derivedData"
  rm -rf "${DERIVED_DATA}"

  if [ "${SIGN_APP}" = "1" ]; then
    echo "Building with code signing enabled..."
    xcodebuild \
      -project "${PROJECT_DIR}/ViType.xcodeproj" \
      -scheme "ViType" \
      -configuration "Release" \
      -derivedDataPath "${DERIVED_DATA}" \
      CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
      DEVELOPMENT_TEAM="${TEAM_ID}" \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGNING_REQUIRED=YES \
      OTHER_CODE_SIGN_FLAGS="--options=runtime" \
      build
  else
    echo "Building without code signing..."
    xcodebuild \
      -project "${PROJECT_DIR}/ViType.xcodeproj" \
      -scheme "ViType" \
      -configuration "Release" \
      -derivedDataPath "${DERIVED_DATA}" \
      build
  fi

  APP_PATH="${DERIVED_DATA}/Build/Products/Release/ViType.app"
fi

if [ -z "${APP_PATH}" ]; then
  echo "error: --app is required when using --skip-build" >&2
  exit 2
fi

if [ ! -d "${APP_PATH}" ]; then
  echo "error: app not found: ${APP_PATH}" >&2
  exit 1
fi

INFO_PLIST="${APP_PATH}/Contents/Info.plist"
if [ ! -f "${INFO_PLIST}" ]; then
  echo "error: Info.plist not found in app bundle: ${INFO_PLIST}" >&2
  exit 1
fi

# Re-sign Sparkle framework components if signing is enabled
if [ "${SIGN_APP}" = "1" ]; then
  echo ""
  echo "=== Re-signing Sparkle Framework Components ==="

  SPARKLE_FRAMEWORK="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
  if [ -d "${SPARKLE_FRAMEWORK}" ]; then
    # Sign XPC services first (innermost components)
    for xpc in "${SPARKLE_FRAMEWORK}/Versions/B/XPCServices"/*.xpc; do
      if [ -d "${xpc}" ]; then
        echo "Signing $(basename "${xpc}")..."
        codesign --force --options runtime --timestamp \
          --sign "${SIGNING_IDENTITY}" "${xpc}"
      fi
    done

    # Sign Autoupdate binary
    AUTOUPDATE="${SPARKLE_FRAMEWORK}/Versions/B/Autoupdate"
    if [ -f "${AUTOUPDATE}" ]; then
      echo "Signing Autoupdate..."
      codesign --force --options runtime --timestamp \
        --sign "${SIGNING_IDENTITY}" "${AUTOUPDATE}"
    fi

    # Sign Updater.app
    UPDATER_APP="${SPARKLE_FRAMEWORK}/Versions/B/Updater.app"
    if [ -d "${UPDATER_APP}" ]; then
      echo "Signing Updater.app..."
      codesign --force --options runtime --timestamp \
        --sign "${SIGNING_IDENTITY}" "${UPDATER_APP}"
    fi

    # Sign the framework itself
    echo "Signing Sparkle.framework..."
    codesign --force --options runtime --timestamp \
      --sign "${SIGNING_IDENTITY}" "${SPARKLE_FRAMEWORK}"

    # Re-sign the main app to update its seal
    echo "Re-signing ${APP_PATH}..."
    codesign --force --options runtime --timestamp \
      --sign "${SIGNING_IDENTITY}" "${APP_PATH}"
  else
    echo "note: Sparkle.framework not found, skipping framework re-signing"
  fi

  # Verify signatures
  echo ""
  echo "=== Verifying Code Signatures ==="
  if codesign --verify --deep --strict --verbose=2 "${APP_PATH}"; then
    echo "Signature verification passed."
  else
    echo "error: Signature verification failed!" >&2
    exit 1
  fi
fi

# Notarize the app if requested
if [ "${NOTARIZE_APP}" = "1" ]; then
  echo ""
  echo "=== Notarizing App ==="

  NOTARIZE_ZIP="$(mktemp -d)/ViType.zip"
  ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"

  echo "Submitting to Apple notarization service..."
  if [ -n "${APPLE_ID_PASSWORD:-}" ]; then
    xcrun notarytool submit "${NOTARIZE_ZIP}" \
      --apple-id "${APPLE_ID}" \
      --password "${APPLE_ID_PASSWORD}" \
      --team-id "${TEAM_ID}" \
      --wait
  else
    # Use Keychain for password (will prompt or use stored credential)
    xcrun notarytool submit "${NOTARIZE_ZIP}" \
      --apple-id "${APPLE_ID}" \
      --keychain-profile "AC_PASSWORD" \
      --wait 2>/dev/null || \
    xcrun notarytool submit "${NOTARIZE_ZIP}" \
      --apple-id "${APPLE_ID}" \
      --team-id "${TEAM_ID}" \
      --wait
  fi

  rm -f "${NOTARIZE_ZIP}"

  echo "Stapling notarization ticket..."
  xcrun stapler staple "${APP_PATH}"

  echo "Notarization complete."
fi

APP_NAME="$(basename "${APP_PATH}" .app)"
VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "${INFO_PLIST}" 2>/dev/null || true)"
BUILD="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "${INFO_PLIST}" 2>/dev/null || true)"

if [ -z "${VERSION}" ]; then
  VERSION="0.0.0"
fi
if [ -z "${BUILD}" ]; then
  BUILD="0"
fi

mkdir -p "${OUT_DIR}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vitype-dmg.XXXXXX")"
cleanup() {
  rm -rf "${STAGING_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

/usr/bin/ditto "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s "/Applications" "${STAGING_DIR}/Applications"

DMG_BASENAME="${APP_NAME}-${VERSION}(${BUILD}).dmg"
DMG_PATH="${OUT_DIR}/${DMG_BASENAME}"
rm -f "${DMG_PATH}"

# Create a temporary DMG in UDRW format (Read/Write) using HFS+ 
# HFS+ mounts much faster than APFS for disk images
TEMP_DMG="${OUT_DIR}/temp_${DMG_BASENAME}"
rm -f "${TEMP_DMG}"

echo "Creating temporary DMG..."
hdiutil create \
  -volname "${VOLNAME}" \
  -srcfolder "${STAGING_DIR}" \
  -fs "HFS+" \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -ov \
  "${TEMP_DMG}"

echo "Converting to compressed DMG..."
hdiutil convert "${TEMP_DMG}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${DMG_PATH}"

rm -f "${TEMP_DMG}"

# Code sign the DMG if signing is enabled (speeds up Gatekeeper verification on mount)
if [ "${SIGN_APP}" = "1" ]; then
  echo "Signing DMG..."
  codesign --force --sign "${SIGNING_IDENTITY}" "${DMG_PATH}" || true
fi

echo "Created optimized DMG: ${DMG_PATH}"

# Generate EdDSA signature for Sparkle updates
echo ""
echo "=== Sparkle EdDSA Signing ==="

SPARKLE_SIGN=""
# Try to find sign_update in DerivedData (from SPM build)
if [ -d "${DERIVED_DATA}/SourcePackages/artifacts/sparkle/Sparkle/bin" ]; then
    SPARKLE_SIGN="${DERIVED_DATA}/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
fi

# Fallback: search in common DerivedData locations
if [ ! -x "${SPARKLE_SIGN}" ]; then
    SPARKLE_SIGN=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1)
fi

if [ -x "${SPARKLE_SIGN}" ]; then
    echo "Using sign_update: ${SPARKLE_SIGN}"
    EDDSA_OUTPUT=$("${SPARKLE_SIGN}" "${DMG_PATH}" 2>&1 || true)
    if [ -n "${EDDSA_OUTPUT}" ]; then
        echo ""
        echo "EdDSA Signature Info:"
        echo "${EDDSA_OUTPUT}"
        echo ""
        # Extract just the signature value for appcast.xml
        EDDSA_SIG=$(echo "${EDDSA_OUTPUT}" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"$//' || true)
        if [ -n "${EDDSA_SIG}" ]; then
            echo "sparkle:edSignature value: ${EDDSA_SIG}"
        fi
        echo ""
        echo "DMG file size (bytes) for appcast.xml length attribute:"
        stat -f%z "${DMG_PATH}"
        # Save signature info to file for reference
        echo "${EDDSA_OUTPUT}" > "${DMG_PATH}.eddsa"
        echo ""
        echo "Signature info saved to: ${DMG_PATH}.eddsa"
    else
        echo "warning: Failed to generate EdDSA signature. Is the private key in Keychain?"
        echo "         Run 'generate_keys' from Sparkle to create keys if needed."
    fi
else
    echo "note: Sparkle sign_update tool not found."
    echo "      Build the project in Xcode first to download Sparkle via SPM."
    echo "      Then re-run this script to generate the EdDSA signature."
fi

