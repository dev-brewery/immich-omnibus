#!/bin/bash
# Investigate @img/sharp-libvips-linux-x64 npm package — what libs it bundles,
# what version of libvips, whether it's ABI-compatible with sharp 0.34.5's
# prebuilt sharp-linux-x64.node.
set -e
TD=$(mktemp -d)
cd "$TD"

echo "=== sharp 0.34.5 deps ==="
# sharp declares @img/sharp-libvips-* as optionalDependencies. Look up what
# version range 0.34.5 requires.
curl -fsSL "https://registry.npmjs.org/sharp/0.34.5" 2>/dev/null | \
    python3 -c 'import sys,json; d=json.load(sys.stdin); print(json.dumps({k:v for k,v in (d.get("optionalDependencies") or {}).items() if "libvips" in k}, indent=2))' || echo "jq/python fallback failed"

echo ""
echo "=== Fetch @img/sharp-libvips-linux-x64 latest ==="
npm_meta=$(curl -fsSL "https://registry.npmjs.org/@img/sharp-libvips-linux-x64")
version=$(echo "$npm_meta" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["dist-tags"]["latest"])')
tarball=$(echo "$npm_meta" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['versions']['$version']['dist']['tarball'])")
echo "latest=$version tarball=$tarball"

echo ""
echo "=== Download and list contents ==="
curl -fsSL -o pkg.tgz "$tarball"
tar -tzf pkg.tgz | head -40
echo "..."
echo "=== .so files in package ==="
tar -tzf pkg.tgz | grep -E '\.so[0-9.]*$'
echo ""
echo "=== Extract + size check ==="
mkdir -p extracted
tar -xzf pkg.tgz -C extracted
find extracted -name '*.so*' -printf '%s %p\n' | sort -rn | head -25

cd /
rm -rf "$TD"
