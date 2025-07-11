#!/bin/bash

set -e

if [ -t 0 ]; then
  if [ -z "$1" ]; then
    echo "Usage:"
    echo "  $0 file.txt           # Copy file contents"
    echo "  echo 'text' | $0      # Copy from pipe"
    exit 1
  fi
  cat "$1" | xclip -selection clipboard
else
  cat - | xclip -selection clipboard
fi

echo "✅ Copied to clipboard!"

