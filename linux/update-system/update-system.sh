#!/bin/bash

set -e

echo "🔄 Starting full system update..."

# Update official packages
echo "📦 Updating official packages (pacman)..."
sudo pacman -Syu

# Update AUR packages
echo "🧩 Updating AUR packages (pamac)..."
pamac upgrade --aur

echo "✅ System update completed!"
