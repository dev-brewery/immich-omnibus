#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== libvips files in /usr/local/lib ==="
ls -la /usr/local/lib/libvips* 2>&1 | head -10
echo ""
echo "=== ldconfig shows libvips ==="
ldconfig -p | grep libvips
echo ""
echo "=== find immich app-server dir ==="
ls -d /opt/immich* 2>&1
ls -la /opt/immich-server 2>&1 | head -5
echo ""
echo "=== sharp module location ==="
find /opt/immich-server -name "sharp-linux-*.node" 2>/dev/null
echo ""
echo "=== attempt require(sharp) ==="
cd /opt/immich-server 2>/dev/null && node -e "
try {
  const s = require(\"sharp\");
  console.log(\"SHARP OK\", JSON.stringify(s.versions));
} catch (e) {
  console.log(\"SHARP FAIL:\", e.message.split(\"\\n\")[0]);
}
" 2>&1 | head -5
'
