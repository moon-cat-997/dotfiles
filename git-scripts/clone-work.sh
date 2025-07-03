#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: clone-work user/repo"
  exit 1
fi

TARGET_DIR=~/Projects/JuliusAgency/$(basename "$1" .git)

echo "Cloning with work identity (ivanovdm812@gmail.com)"
git clone git@github.com:$1 "$TARGET_DIR"
