#!/bin/sh
set -e

PATH_SPEC="$1"
shift
COMMAND="$@"

if [ -z "$PATH_SPEC" ] || [ -z "$COMMAND" ]; then
  echo "Usage: wait-for-path.sh <file_or_glob> <command_to_execute>"
  exit 1
fi

# Check if PATH_SPEC contains a glob character.
is_glob=false
case "$PATH_SPEC" in
  *[\*\?]*) is_glob=true ;;
esac

if [ "$is_glob" = true ]; then
  DIR=$(dirname "$PATH_SPEC")
  PATTERN=$(basename "$PATH_SPEC")
  
  echo "Waiting for files matching pattern '$PATTERN' in directory '$DIR'..."
  while ! find "$DIR" -maxdepth 1 -name "$PATTERN" -print -quit | grep -q .; do
    echo "Still waiting for files matching: $PATH_SPEC"
    sleep 10
  done
  echo "Found file(s) matching '$PATH_SPEC'."
else
  echo "Waiting for file: $PATH_SPEC..."
  while [ ! -f "$PATH_SPEC" ]; do
    echo "Still waiting for file: $PATH_SPEC"
    sleep 10
  done
  echo "Found file: $PATH_SPEC."
fi

echo "Executing: $COMMAND"
exec $COMMAND
