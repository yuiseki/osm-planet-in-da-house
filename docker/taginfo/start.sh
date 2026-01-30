#!/usr/bin/env sh
set -eu

DATA_DIR="/usr/src/app/data"
MASTER_DB="${DATA_DIR}/taginfo-master.db"

if [ -f "$MASTER_DB" ]; then
  sqlite3 "$MASTER_DB" "delete from sources where id = 'chronology';"
else
  echo "Warning: ${MASTER_DB} not found. Skip removing chronology source." >&2
fi

cd /usr/src/app/taginfo/web
exec bundle exec ruby taginfo.rb -o 0.0.0.0 -p 4567
