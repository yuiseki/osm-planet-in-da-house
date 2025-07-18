latest_url=$(curl -LIs --max-redirs 1 -o /dev/null -w '%{url_effective}' 'https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf' || true)
latest_osm_pbf=$(basename "$latest_url")

docker run \
    -u `id -u`:`id -g` \
    --memory 90g \
    --memory-swap 90g \
    --memory-swappiness 10 \
    -e JAVA_TOOL_OPTIONS="-XX:+AlwaysPreTouch -Xms28g -Xmx28g" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        --area=planet \
        --bounds=planet \
        --download \
        --download-threads=16 \
        --download-chunk-size-mb=1000 \
        --fetch-wikidata \
        --nodemap-type=sparsearray \
        --nodemap-storage=mmap \
        --osm-path=/data/${latest_osm_pbf} \
        --force
