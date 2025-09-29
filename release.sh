#!/usr/bin/env bash
set -e

# 1️⃣ Get version from your commit message
COMMIT_MSG=$(git log -1 --pretty=%B)
if [[ "$COMMIT_MSG" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  VERSION="${BASH_REMATCH[0]}"
else
  echo "No version found in commit message. Please include vX.Y.Z in your last commit."
  exit 1
fi
echo "Version: $VERSION"

# 2️⃣ Create and push Git tag
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

# 3️⃣ Build the binary
swift build -c release --disable-sandbox

# 4️⃣ Package it
mkdir -p dist
cp .build/release/netcaps dist/
tar -czf "netcaps-$VERSION-macos.tar.gz" -C dist netcaps
echo "Packaged netcaps-$VERSION-macos.tar.gz"

# 5️⃣ Compute SHA256
SHA=$(shasum -a 256 "netcaps-$VERSION-macos.tar.gz" | awk '{print $1}')
echo "SHA256: $SHA"

# Done
echo "Release $VERSION ready locally!"