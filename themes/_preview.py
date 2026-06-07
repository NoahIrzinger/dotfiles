#!/usr/bin/env python3
"""Render a tmux status bar to a PNG. Design tool for custom headers.

Usage: _preview.py <tmux-conf> <out.png> [cols] [rows]

capture-pane can't grab the status bar (not pane content), so this spins a
throwaway tmux server, attaches over a pty, runs the byte stream through the pyte
terminal emulator to rebuild the cell grid, and draws each cell (bg rect + fg
glyph) with Pillow + a Nerd Font. You see the real bar (pill caps, module values)
without screenshotting your own session.

Deps: pip install pyte pillow; plus a Nerd Font in ~/Library/Fonts.
"""
import os, sys, pty, time, select, glob

try:
    import pyte
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:  # pragma: no cover
    sys.exit(f"preview needs pyte + pillow ({e}); run: pip3 install pyte pillow")

# pyte 0.8.x raises on tmux's private DSR/DA query replies; neuter those handlers.
pyte.Screen.report_device_status = lambda self, *a, **k: None
pyte.Screen.report_device_attributes = lambda self, *a, **k: None

conf = sys.argv[1]
out = sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 140
rows = int(sys.argv[4]) if len(sys.argv) > 4 else 6

CW, CH, PT = 13, 28, 22          # cell width/height (px) and font point size
DEF_BG, DEF_FG = "#0a0a0f", "#f5e6d0"


def find_font():
    pats = ["MesloLGSNerdFontMono-Regular", "*NerdFontMono-Regular",
            "*NerdFont-Regular", "*Mono-Regular"]
    dirs = [os.path.expanduser("~/Library/Fonts"), "/Library/Fonts",
            "/System/Library/Fonts"]
    for p in pats:
        for d in dirs:
            hits = sorted(glob.glob(os.path.join(d, p + ".ttf")))
            if hits:
                return hits[0]
    return None


def capture():
    """Load `conf` in a throwaway tmux, sample a few windows, return the cell grid."""
    L = "themeprev%d" % os.getpid()
    os.system(f"tmux -L {L} -f {conf} new-session -d -s main -x {cols} -y {rows} 2>/dev/null")
    os.system(f"tmux -L {L} rename-window code 2>/dev/null")
    for nm in ("nvim", "zsh"):
        os.system(f"tmux -L {L} new-window -n {nm} 2>/dev/null")
    os.system(f"tmux -L {L} select-window -t :2 2>/dev/null")

    screen = pyte.Screen(cols, rows)
    stream = pyte.ByteStream(screen)
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.execvp("tmux", ["tmux", "-L", L, "attach"])
    t = time.time()
    last = 0.0
    while time.time() - t < 10:          # settle: cpu/ram #() scripts sample ~2s
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                d = os.read(fd, 65536)
            except OSError:
                break
            if not d:
                break
            try:
                stream.feed(d)
            except Exception:
                pass
        if time.time() - t - last > 0.8:  # nudge redraws so async #() cache fills
            last = time.time() - t
            os.system(f"tmux -L {L} refresh-client 2>/dev/null")
    os.system(f"tmux -L {L} kill-server 2>/dev/null")
    return screen.buffer


def color(c, default):
    if not c or c == "default":
        return default
    if len(c) == 6:
        try:
            int(c, 16)
            return "#" + c
        except ValueError:
            return default
    return default


def main():
    font_path = find_font()
    if not font_path:
        sys.exit("no Nerd/monospace font found in ~/Library/Fonts")
    font = ImageFont.truetype(font_path, PT)
    buf = capture()
    img = Image.new("RGB", (cols * CW, rows * CH), DEF_BG)
    dr = ImageDraw.Draw(img)
    for y in range(rows):
        for x in range(cols):
            ch = buf[y][x]
            bg = color(ch.bg, DEF_BG)
            fg = color(ch.fg, DEF_FG)
            if ch.reverse:
                bg, fg = fg, bg
            dr.rectangle([x * CW, y * CH, (x + 1) * CW, (y + 1) * CH], fill=bg)
            if ch.data and ch.data != " ":
                dr.text((x * CW, y * CH), ch.data, font=font, fill=fg)
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
