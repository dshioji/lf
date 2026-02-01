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
| Keybindings | opts.go | J, K, Shift+arrows, Shift+PgUp/Dn, Shift+mouse scroll |

---

## All Preview Scroll Keybindings

| Key | Action |
|-----|--------|
| `J` | scroll preview down 1 line |
| `K` | scroll preview up 1 line |
| `Shift+↓` | scroll preview down 1 line |
| `Shift+↑` | scroll preview up 1 line |
| `Shift+PgDn` | scroll preview down 1 page |
| `Shift+PgUp` | scroll preview up 1 page |
| `Shift+MouseWheelDown` | scroll preview down 3 lines |
| `Shift+MouseWheelUp` | scroll preview up 3 lines |

### Mouse Scroll Implementation (ui.go)
```go
// Line 1669-1673
if tev.Modifiers() == tcell.ModCtrl {
    button = "<c-" + button[1:]
} else if tev.Modifiers() == tcell.ModShift {
    button = "<s-" + button[1:]
}
```

Maps to `<s-m-up>` and `<s-m-down>` keybindings in opts.go.

---

## Issue 3: Shift+MouseWheel Not Working

### Potential Causes

#### 1. Mouse Disabled (Most Likely)
Mouse events are **disabled by default** in lf.

**Fix:** Add to `~/.config/lf/lfrc`:
```
set mouse
```

#### 2. Terminal Compatibility (Windows Terminal / WSL)
Some terminals don't send shift modifier with mouse scroll events. Windows Terminal may have this limitation.

**How to Test:**
Run lf_fork and try Shift+MouseWheel. If you see no error message at all, mouse events aren't being received (mouse disabled). If you see "unknown mapping: <m-down>", the shift modifier isn't being sent by terminal.

#### 3. Debug: Check What Events Are Received
The code at ui.go:1677-1678 shows error for unknown mappings:
```go
if button != "<m-1>" && button != "<m-2>" {
    ui.echoerrf("unknown mapping: %s", button)
}
```

If you see:
- `unknown mapping: <m-down>` → Shift not sent by terminal
- `unknown mapping: <s-m-down>` → Keybinding not found (shouldn't happen now)
- No message → Mouse disabled OR event eaten by special handling

### Configuration Required

Add to `~/.config/lf/lfrc`:
```
# Enable mouse
set mouse

# Optional: explicit keybindings (already default in fork)
map <s-m-down> preview-scroll-down
map <s-m-up> preview-scroll-up
```

### Terminal-Specific Notes

| Terminal | Shift+MouseWheel Support |
|----------|-------------------------|
| Windows Terminal (WSL) | May not work - terminal limitation |
| Alacritty | Works |
| iTerm2 | Works |
| Kitty | Works |
| xterm | Works with proper config |

### Workaround if Terminal Doesn't Support Shift+Mouse
Use keyboard shortcuts instead:
- `J` / `K` - scroll 1 line
- `Shift+PgDn` / `Shift+PgUp` - scroll 1 page

---

## Issue 4: Mouse Wheel Over Preview Was Ignored

### Root Cause
In ui.go lines 1692-1700, when mouse is over preview pane with a file (not directory):
```go
} else if !curr.IsDir() || gOpts.dirpreviews {
    if tev.Buttons() != tcell.Button2 {
        return nil  // ALL events except middle-click ignored!
    }
    return &callExpr{"open", nil, 1}
}
```

Mouse wheel events (`WheelUp`, `WheelDown`) were being discarded.

### Fix
Modified to handle wheel events in preview pane:
```go
} else if !curr.IsDir() || gOpts.dirpreviews {
    switch tev.Buttons() {
    case tcell.WheelDown:
        return &callExpr{"preview-scroll-down", nil, 3}
    case tcell.WheelUp:
        return &callExpr{"preview-scroll-up", nil, 3}
    case tcell.Button2:
        return &callExpr{"open", nil, 1}
    default:
        return nil
    }
}
```

### Result
Now **mouse wheel over preview pane scrolls the preview automatically** - no Shift key needed!

---

## Issue 5: Mouse Wheel Keybindings Override Position Check

### Root Cause
In opts.go, mouse wheel is globally mapped:
```go
"<m-up>":   &callExpr{"up", nil, 1},    // line 289
"<m-down>": &callExpr{"down", nil, 1},  // line 297
```

The event flow was:
1. Mouse wheel event received
2. Convert to `<m-up>` or `<m-down>`
3. **Keybinding lookup FIRST** → finds `up`/`down` mapping
4. Returns immediately → **never reaches position check**

### Fix
Check mouse position **before** keybinding lookup for wheel events:
```go
case *tcell.EventMouse:
    // Check position first for wheel events
    x, y := tev.Position()
    wind, _ := ui.winAt(x, y)

    // Handle mouse wheel over preview pane BEFORE keybinding lookup
    if gOpts.preview && wind == len(ui.wins)-1 {
        if tev.Buttons() == tcell.WheelDown || tev.Buttons() == tcell.WheelUp {
            curr := nav.currFile()
            if curr != nil && (!curr.IsDir() || gOpts.dirpreviews) {
                if tev.Buttons() == tcell.WheelDown {
                    return &callExpr{"preview-scroll-down", nil, 3}
                }
                return &callExpr{"preview-scroll-up", nil, 3}
            }
        }
    }
    // ... then continue with keybinding lookup for other cases
```

## Final Keybindings Summary

| Key | Action |
|-----|--------|
| `J` | scroll preview down 1 line |
| `K` | scroll preview up 1 line |
| `Shift+↓` | scroll preview down 1 line |
| `Shift+↑` | scroll preview up 1 line |
| `Shift+PgDn` | scroll preview down 1 page |
| `Shift+PgUp` | scroll preview up 1 page |
| MouseWheel over preview | scroll preview 3 lines (position-aware) |
| MouseWheel over file list | scroll files (unchanged) |
