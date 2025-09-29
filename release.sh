#!/usr/bin/env bash
set -e

echo "Version: 1.4.0"

# 2️⃣ Create and push Git tag
git tag -a "1.4.0" -m "v1.4.0"
git push origin "1.4.0"

# 3️⃣ Build the binary
swift build -c release --disable-sandbox

# 4️⃣ Package it
mkdir -p dist
cp .build/release/netcaps dist/
tar -czf "netcaps-$VERSION-macos.tar.gz" -C dist netcaps
echo "Packaged netcaps-$VERSION-macos.tar.gz"

# 5️⃣ Compute SHA256
SHA=$(shasum -a 256 "netcaps-1.4.0-macos.tar.gz" | awk '{print $1}')
echo "SHA256: $SHA"

# Done
echo "Release $VERSION ready locally!"