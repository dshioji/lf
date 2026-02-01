#!/bin/bash
set -e

cd "$(dirname "$0")"

BINARY_NAME="lf"

if [[ "$1" == "--fork" ]]; then
    BINARY_NAME="lf_fork"
fi

echo "Building lf..."
CGO_ENABLED=0 go build -ldflags="-s -w"

mkdir -p ~/bin

echo "Installing as $BINARY_NAME to ~/bin..."
cp lf ~/bin/$BINARY_NAME

echo "Done. Make sure ~/bin is in your PATH."
