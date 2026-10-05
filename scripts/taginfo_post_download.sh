#!/usr/bin/env bash
#
# taginfo_post_download.sh
#
# The distributed taginfo-db.db is taken from upstream's sources/update_all.sh
# at the point where it is compressed for download. Two later stages are not
# in it:
#
#   create_extra_indexes : db/add_extra_indexes.sql and db/add_ftsearch.sql
#   update_master        : master/master.sql fills in_wiki, in_wiki_en and
#                          projects on taginfo-db.db's keys and tags
#
# Without them:
#
#   api/4/search/by_value always returns 0 results. The ftsearch table does
#     not exist, and web/lib/api/v4/search.rb turns the exception into
#     total = 0, so the missing table never surfaces as an error.
#   in_wiki is false for every key
#   projects is always 0
#
# Run this whenever taginfo-db.db is replaced.
#
set -euo pipefail

DEST_DIR="${1:-$(pwd)/data/taginfo}"
SQLITE="${SQLITE:-sqlite3}"
DB="$DEST_DIR/taginfo-db.db"

for f in taginfo-db.db taginfo-wiki.db taginfo-master.db; do
  if [ ! -f "$DEST_DIR/$f" ]; then
    echo "Missing $DEST_DIR/$f" >&2
    exit 1
  fi
done

# Check up front: a sqlite3 without FTS5 would fail halfway through
if ! "$SQLITE" :memory: "CREATE VIRTUAL TABLE t USING fts5(a);" >/dev/null 2>&1; then
  echo "$SQLITE does not support FTS5" >&2
  exit 1
fi

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "add_extra_indexes: indexes first, so the updates below are not full scans"
"$SQLITE" "$DB" <<'SQL'
PRAGMA cache_size = -2000000;
PRAGMA temp_store = FILE;
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
CREATE INDEX IF NOT EXISTS tags_key_count_nodes_idx     ON tags (key, count_nodes     DESC);
CREATE INDEX IF NOT EXISTS tags_key_count_ways_idx      ON tags (key, count_ways      DESC);
CREATE INDEX IF NOT EXISTS tags_key_count_relations_idx ON tags (key, count_relations DESC);
CREATE UNIQUE INDEX IF NOT EXISTS tags_key_value_idx    ON tags (key, value);
SQL

say "master.sql: the part that writes to taginfo-db.db"
"$SQLITE" "$DB" <<SQL
PRAGMA cache_size = -2000000;
PRAGMA temp_store = FILE;
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
ATTACH DATABASE 'file:$DEST_DIR/taginfo-wiki.db?mode=ro'   AS wiki;
ATTACH DATABASE 'file:$DEST_DIR/taginfo-master.db?mode=ro' AS master;

INSERT INTO keys (key) SELECT DISTINCT key FROM wiki.wikipages WHERE key NOT IN (SELECT key FROM keys);

UPDATE keys SET in_wiki=1    WHERE key IN (SELECT DISTINCT key FROM wiki.wikipages WHERE value IS NULL);
UPDATE keys SET in_wiki_en=1 WHERE key IN (SELECT DISTINCT key FROM wiki.wikipages WHERE value IS NULL AND lang='en');
UPDATE keys SET projects=(SELECT projects FROM master.project_unique_keys p WHERE p.key=keys.key);

UPDATE tags SET in_wiki=1    WHERE key IN (SELECT DISTINCT key FROM wiki.wikipages WHERE value IS NOT NULL AND value != '*') AND key || '=' || value IN (SELECT DISTINCT tag FROM wiki.wikipages WHERE value IS NOT NULL AND value != '*');
UPDATE tags SET in_wiki_en=1 WHERE key IN (SELECT DISTINCT key FROM wiki.wikipages WHERE value IS NOT NULL AND value != '*' AND lang='en') AND key || '=' || value IN (SELECT DISTINCT tag FROM wiki.wikipages WHERE value IS NOT NULL AND value != '*' AND lang='en');

ANALYZE keys;
ANALYZE tags;
SQL

say "add_ftsearch: full text search over every row of tags. The slow one."
"$SQLITE" "$DB" <<'SQL'
PRAGMA cache_size = -4000000;
PRAGMA temp_store = FILE;
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
DROP TABLE IF EXISTS ftsearch;
CREATE VIRTUAL TABLE ftsearch USING fts5 (content='tags', key, value, count_all UNINDEXED);
INSERT INTO ftsearch (key, value, count_all) SELECT key, value, count_all FROM tags;
ANALYZE ftsearch;
SQL

say "verify"
"$SQLITE" "$DB" <<'SQL'
.mode list
SELECT 'keys in_wiki=1      ' || count(*) FROM keys WHERE in_wiki=1;
SELECT 'keys projects>0     ' || count(*) FROM keys WHERE projects>0;
SELECT 'tags in_wiki=1      ' || count(*) FROM tags WHERE in_wiki=1;
SELECT 'ftsearch rows       ' || count(*) FROM ftsearch;
SELECT 'ftsearch MATCH ramen' || ' ' || count(*) FROM ftsearch WHERE ftsearch MATCH 'ramen';
SQL

say "done. Restart the taginfo pod: SQLite attaches the files at startup."
