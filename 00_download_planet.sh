latest_url=$(curl -LIs --max-redirs 1 -o /dev/null -w '%{url_effective}' 'https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf' || true)
latest_osm_pbf=$(basename "$latest_url")

aria2c -d data "https://planet.openstreetmap.org/pbf/${latest_osm_pbf}.md5"
aria2c \
  -d data \
  --seed-time=0 \
  "https://planet.openstreetmap.org/pbf/${latest_osm_pbf}.torrent"
cd data
md5sum -c "${latest_osm_pbf}.md5"
if [ $? -ne 0 ]; then
  echo "MD5 checksum failed for ${latest_osm_pbf}. Download may be corrupted."
  exit 1
fi
cd ..
