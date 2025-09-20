# WIP

#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: add-remote-personal remote-name link"
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "Usage: add-remote-personal remote-name link"
  exit 1
fi

TARGET_DIR=~/Projects/Own/$(basename "$1" .git)

echo "Cloning with personal identity (ivanovdmit812@gmail.com)"
git clone git@github-personal:$1 "$TARGET_DIR"
