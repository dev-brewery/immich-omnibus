#!/bin/bash
set -e
BASE=/home/LOCAL_USER/projects/immich-omnibus
SRC=/mnt/LOCAL_DRIVE/LOCAL_STAGING_DIR
cp "$SRC/tmp_init.sh"          "$BASE/scripts/init.sh"
cp "$SRC/tmp_postgres_run"     "$BASE/s6/services/postgres/run"
cp "$SRC/tmp_immich_server_run" "$BASE/s6/services/immich-server/run"
cp "$SRC/tmp_backup.sh"        "$BASE/scripts/backup.sh"
cp "$SRC/tmp_test.sh"          "$BASE/test.sh"
chmod +x "$BASE/scripts/init.sh" "$BASE/s6/services/postgres/run" "$BASE/s6/services/immich-server/run" "$BASE/scripts/backup.sh" "$BASE/test.sh"
rm "$SRC/tmp_init.sh" "$SRC/tmp_postgres_run" "$SRC/tmp_immich_server_run" "$SRC/tmp_backup.sh" "$SRC/tmp_test.sh"
for f in scripts/init.sh scripts/backup.sh s6/services/postgres/run s6/services/immich-server/run test.sh; do
    echo "=== $f ==="
    bash -n "$BASE/$f" && echo "  syntax OK"
    head -c 2 "$BASE/$f"
    echo
done
