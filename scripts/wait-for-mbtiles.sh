#!/bin/sh
set -e

# Path to the data directory
DATA_DIR="/data"

# Loop until at least one .mbtiles file is found
while ! find "$DATA_DIR" -maxdepth 1 -name "*.mbtiles" -print -quit | grep -q .; do
  echo "Waiting for .mbtiles file in $DATA_DIR..."
  sleep 10
done

echo "Found mbtiles file. Starting tileserver-gl..."
# Execute the original entrypoint/command for the maptiler/tileserver-gl image
exec /run.sh
