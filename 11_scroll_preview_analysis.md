# Preview Scroll Key Mapping Analysis

## Issue
When pressing Shift+arrow keys, lf shows "unknown mapping: <s-down>" error.

## How LF Key Handling Works

### Key Event Flow (ui.go)
1. Terminal sends key event via tcell
2. LF processes in `readNormalEvent()` (line 1547)
3. Two paths:
   - **KeyRune** (regular characters): Capital letters like `J`, `K` are stored directly as the character
   - **Special keys** (arrows, pgup, etc.): Converted via `gKeyVal` map, then `addSpecialKeyModifier()` adds `<s-`, `<c-`, `<a-` prefixes

### Capital Letters vs Shift+Key
```
Shift+J → Terminal sends 'J' (KeyRune) → LF stores as "J"
Shift+↓ → Terminal sends KeyDown+ModShift → LF stores as "<s-down>"
```

## Current Keybindings (opts.go)

| Key | Mapping | Works? |
|-----|---------|--------|
| `J` | preview-scroll-down | YES |
| `K` | preview-scroll-up | YES |
| `<s-pgdn>` | preview-page-down | YES |
| `<s-pgup>` | preview-page-up | YES |
| `<s-down>` | (none) | NO - causes error |
| `<s-up>` | (none) | NO - causes error |

## Solution Options

### Option 1: Use Capital Letters (Current - Already Works)
Press `J` and `K` directly (not thinking of it as Shift+j/k).

### Option 2: Add Shift+Arrow Bindings
Add to lfrc or opts.go:
```
map <s-down> preview-scroll-down
map <s-up> preview-scroll-up
```

### Option 3: User Config (lfrc)
Add to `~/.config/lf/lfrc`:
```
map J preview-scroll-down
map K preview-scroll-up
map <s-down> preview-scroll-down
map <s-up> preview-scroll-up
map <s-pgdn> preview-page-down
map <s-pgup> preview-page-up
```

## Recommendation
The `J` and `K` bindings should already work. If user is pressing Shift+Down arrow expecting it to work, they need to either:
1. Use `J`/`K` instead
2. Add `<s-down>`/`<s-up>` mappings to their lfrc

## Available Preview Scroll Commands
- `preview-scroll-up` - scroll 1 line up
- `preview-scroll-down` - scroll 1 line down
- `preview-half-up` - scroll half page up
- `preview-half-down` - scroll half page down
- `preview-page-up` - scroll full page up
- `preview-page-down` - scroll full page down
