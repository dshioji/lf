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

---

## Issue 2: Preview Scroll Not Working (No Error)

### Symptom
Keys are recognized (no "unknown mapping" error) but preview doesn't scroll.

### Root Cause Analysis

#### How Preview Content is Generated (nav.go)

```go
// nav.go line 952 (BEFORE FIX)
lines, binary, sixel := readLines(reader, win.h)
```

The `readLines()` function in `misc.go` reads file content with a **line limit**.
Originally it was called with `win.h` (window height) - meaning only enough lines to fill the preview window were loaded.

**Result:** If preview window is 30 lines, only 30 lines are read. Nothing to scroll!

#### Preview Data Flow
```
File → readLines(reader, maxLines) → reg.lines[] → printReg() with offset
```

1. `preview()` reads file content (nav.go:876)
2. `readLines()` caps at `maxLines` parameter (misc.go:454)
3. Lines stored in `reg.lines[]`
4. `printReg()` renders from `reg.offset` (ui.go:250)

#### The Fix (nav.go)
```go
// Read more lines than window height to enable scrolling
maxLines := win.h * 10
if maxLines < 500 {
    maxLines = 500
}
lines, binary, sixel := readLines(reader, maxLines)
```

Now reads 10x window height (minimum 500 lines) to enable scrolling.

### Implementation Details

#### reg struct (ui.go)
```go
type reg struct {
    loading  bool
    volatile bool
    loadTime time.Time
    path     string
    lines    []string  // preview content
    sixel    bool
    offset   int       // scroll position (ADDED)
}
```

#### previewScrollDown (nav.go)
```go
func (nav *nav) previewScrollDown(dist int) bool {
    reg, ok := nav.regCache[curr.path]
    maxOffset := len(reg.lines) - nav.height
    reg.offset += dist
    if reg.offset > maxOffset {
        reg.offset = maxOffset
    }
    return old != reg.offset
}
```

#### printReg rendering (ui.go)
```go
lines := reg.lines
if reg.offset > 0 && reg.offset < len(lines) {
    lines = lines[reg.offset:]  // Start from offset
}
for i, l := range lines {
    if i > win.h-1 {
        break
    }
    st = win.print(screen, 0, i, st, l)
}
```

### Summary
| Component | File | Change |
|-----------|------|--------|
| reg.offset field | ui.go | Added scroll position tracking |
| readLines limit | nav.go | Increased from win.h to win.h*10 (min 500) |
| previewScrollUp/Down | nav.go | New methods to modify offset |
| printReg | ui.go | Render from offset position |
| Commands | eval.go | 6 new preview scroll commands |
| Keybindings | opts.go | J, K, Shift+arrows, Shift+PgUp/Dn |
