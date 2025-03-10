#!/bin/bash

APP_NAME="Dual.app"
CONTENTS="$APP_NAME/Contents"
BUNDLE_ID="com.santhoshr.dual"

# Read version from VERSION file
VERSION=$(cat VERSION)
if [ -z "$VERSION" ]; then
    echo "Error: Could not read version from VERSION file"
    exit 1
fi
echo "Building version $VERSION"

# Get current OS version for plist
CURRENT_OS=$(sw_vers -buildVersion)
MACOS_VERSION=$(sw_vers -productVersion)

# Clean previous build but preserve code signing identity
if [ -d "$APP_NAME" ]; then
    PREV_SIGNATURE=$(codesign -dvv "$APP_NAME" 2>&1 | grep "Authority" || true)
fi

rm -rf "$APP_NAME"
mkdir -p "$CONTENTS"/{MacOS,Resources}

# First ensure we have a fresh build
make clean && make

# Copy binary and make executable
cp bin/dual "$CONTENTS/MacOS/"
chmod +x "$CONTENTS/MacOS/dual"

# Copy resources
cp VERSION "$CONTENTS/Resources/"
cp Resources/DualKeyboardLogo.jpg "$CONTENTS/Resources/" || echo "Warning: Logo not found, will use built-in logo"
cp Resources/DualKeyboardLogo.icns "$CONTENTS/Resources/" || echo "Warning: Icon not found, will use built-in icon"

# Get Development Team ID and identity
TEAM_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | cut -d '"' -f 2 | cut -d "(" -f 2 | cut -d ")" -f 1)
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | cut -d '"' -f 2)

# Process Info.plist
sed -e "s/\$(CURRENT_MAC_OS_VERSION)/$CURRENT_OS/g" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/$MACOS_VERSION/g" \
    -e "s/\$(DEVELOPMENT_TEAM)/$TEAM_ID/g" \
    -e "s/\$(CURRENT_PROJECT_VERSION)/$(date +%Y%m%d.%H%M%S)/g" \
    -e "s/\$(APP_VERSION)/$VERSION/g" \
    Info.plist > "$CONTENTS/Info.plist"

# Create bundle references
CERT_NAME="dual-codesign-cert"
BUNDLE_REF="com.santhoshr.dual"

# Proper signing with explicit certificate and bundle ID
codesign --force \
         --sign "$CERT_NAME" \
         --options runtime \
         --timestamp \
         --identifier "$BUNDLE_REF" \
         --entitlements entitlements.plist \
         --deep \
         "$APP_NAME"

echo "Basic signature applied. You may need to approve in Security & Privacy settings."

# Verify with explicit requirements
echo "Verifying code signature..."
codesign --verify --verbose=4 "$APP_NAME"
codesign --display --entitlements - "$APP_NAME"
spctl --assess --type execute --verbose=4 "$APP_NAME"

