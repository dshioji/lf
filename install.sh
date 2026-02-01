#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building lf..."
CGO_ENABLED=0 go build -ldflags="-s -w"

mkdir -p ~/bin

echo "Installing lf to ~/bin..."
cp lf ~/bin/

echo "Done. Make sure ~/bin is in your PATH."
