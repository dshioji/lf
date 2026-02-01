# LF Build & Install Instructions

## Prerequisites
- Go 1.21+ installed

## Build
```bash
cd lf
CGO_ENABLED=0 go build -ldflags="-s -w"
```

## Install
```bash
./install.sh
```

Or manually:
```bash
cp lf ~/bin/
```

## Verify
```bash
lf --version
```

## Preview Scroll Keybindings
- `J` (Shift+j) - scroll preview down
- `K` (Shift+k) - scroll preview up
- `Shift+PgDn` - page down in preview
- `Shift+PgUp` - page up in preview
