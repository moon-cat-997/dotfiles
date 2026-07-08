#!/bin/bash

CURRENT_DIR="$(pwd)"

JULIUS_DIR="$HOME/Projects/JuliusAgency"
OWN_DIR="$HOME/Projects/Own"

echo "Current directory: $CURRENT_DIR"

if [[ "$CURRENT_DIR" == "$JULIUS_DIR"* ]]; then
  echo "Detected office project (JuliusAgency)"
  config_used="$HOME/.gitconfig-office"
elif [[ "$CURRENT_DIR" == "$OWN_DIR"* ]]; then
  echo "Detected personal project (Own)"
  config_used="$HOME/.gitconfig-personal"
else
  echo "Unknown project location"
  config_used="$HOME/.gitconfig"
fi

echo "🔍 Git config in use: $config_used"

echo
echo "👤 Git Identity in this repo:"
git config user.name
git config user.email
