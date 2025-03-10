#!/bin/bash

# This script updates the version number in all relevant files 
# Usage: ./update-version.sh <new_version>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <new_version>"
    echo "Example: $0 4.1.0"
    exit 1
fi

NEW_VERSION="$1"
OLD_VERSION=$(cat VERSION)

echo "Updating version from $OLD_VERSION to $NEW_VERSION"

# Update the VERSION file
echo -n "$NEW_VERSION" > VERSION

# Update version in README.md
sed -i '' -E "s/(Toggle \*\*Key Display\*\*  \(v)[0-9]+(\.[0-9]+)*(\.[0-9]+)*/\1$NEW_VERSION/g" README.md
sed -i '' -E "s/(DualKeyboard v)[0-9]+(\.[0-9]+)*(\.[0-9]+)*/\1$NEW_VERSION/g" README.md

# Create a new changelog entry if needed
if ! grep -q "## \[v$NEW_VERSION\]" CHANGELOG.md; then
    DATE=$(date +%Y-%m-%d)
    sed -i '' "2i\\
## [v$NEW_VERSION] - $DATE\\
- Version update\\
\\
" CHANGELOG.md
fi

echo "Version updated successfully. Please check the following files:"
echo "- VERSION"
echo "- README.md"
echo "- CHANGELOG.md"
echo ""
echo "Remember to build the app to apply the changes: ./build.sh"