"""Generate Play Store feature graphic variants (1024x500, RGB, no alpha)."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

W, H = 1024, 500
ICON = "/Users/asifshakir/Projects/tsr-app/mobile/design/icon.png"
OUT = "/private/tmp/claude-501/-Users-asifshakir-Projects-tsr-app/21904668-411f-4db7-b155-669c45a9023b/scratchpad/fg"
os.makedirs(OUT, exist_ok=True)

FONT = "/System/Library/Fonts/Avenir Next.ttc"
BOLD, DEMI, REGULAR = 0, 2, 7

PRIMARY = (0x2E, 0x7D, 0x6B)
GOLD = (0xD4, 0xAF, 0x37)
CREAM = (0xF8, 0xF6, 0xF0)
MEDIUM = (0x5D, 0x6D, 0x7E)


def f(sz, idx):
    return ImageFont.truetype(FONT, sz, index=idx)


def width_of(draw, text, fnt):
    b = draw.textbbox((0, 0), text, font=fnt)
    return b[2] - b[0]


def fit(draw, text, idx, max_w, hi=90, lo=20):
    """Largest size whose rendered width fits max_w."""
    best = lo
    while lo <= hi:
        mid = (lo + hi) // 2
        if width_of(draw, text, f(mid, idx)) <= max_w:
            best, lo = mid, mid + 1
        else:
            hi = mid - 1
    return best


def wrap(draw, text, fnt, max_w):
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        t = (cur + " " + w_).strip()
        if width_of(draw, t, fnt) <= max_w or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w_
    if cur:
        lines.append(cur)
    return lines


def medallion(diameter):
    icon = Image.open(ICON).convert("RGBA")
    s = icon.size[0]
    c = s // 2
    r = int(s * 0.405)
    disc = icon.crop((c - r, c - r, c + r, c + r)).resize((diameter, diameter), Image.LANCZOS)
    mask = Image.new("L", (diameter, diameter), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, diameter - 1, diameter - 1), fill=255)
    ring = max(8, int(diameter * 0.075))
    total = diameter + ring * 2
    plate = Image.new("RGBA", (total, total), (0, 0, 0, 0))
    ImageDraw.Draw(plate).ellipse((0, 0, total - 1, total - 1), fill=(255, 255, 255, 255))
    plate.paste(disc, (ring, ring), mask)
    return plate


def drop_shadow(img, blur=20, alpha=55, dy=8):
    sh = Image.new("RGBA", (img.size[0] + 80, img.size[1] + 80), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((40, 40, 40 + img.size[0], 40 + img.size[1]), fill=(0, 0, 0, alpha))
    return sh.filter(ImageFilter.GaussianBlur(blur)), (-40, -40 + dy)


def compose(bg_fn, title_col, tag_col, rule_col, name):
    img = Image.new("RGB", (W, H), CREAM)
    bg_fn(img)

    D = 248
    med = medallion(D)
    mx, my = 72, (H - med.size[1]) // 2
    sh, off = drop_shadow(med)
    img.paste(Image.new("RGB", sh.size, (10, 10, 10)), (mx + off[0], my + off[1]), sh)
    img.paste(med, (mx, my), med)

    d = ImageDraw.Draw(img)
    tx = mx + med.size[0] + 52
    avail = W - tx - 64

    title = "The Strong Rope"
    ts = min(fit(d, title, BOLD, avail), 72)
    f_title = f(ts, BOLD)
    tb = d.textbbox((0, 0), title, font=f_title)
    th = tb[3] - tb[1]

    f_tag = f(27, REGULAR)
    tag_lines = wrap(d, "Connecting hearts to Islamic knowledge", f_tag, avail)
    line_h = 38
    tag_h = line_h * len(tag_lines)

    rule_gap_top, rule_h, rule_gap_bot = 26, 5, 26
    block_h = th + rule_gap_top + rule_h + rule_gap_bot + tag_h
    top = (H - block_h) // 2

    d.text((tx, top - tb[1]), title, font=f_title, fill=title_col)
    ry = top + th + rule_gap_top
    d.rectangle([tx, ry, tx + 92, ry + rule_h], fill=rule_col)
    ty = ry + rule_h + rule_gap_bot
    for i, ln in enumerate(tag_lines):
        d.text((tx, ty + i * line_h), ln, font=f_tag, fill=tag_col)

    path = f"{OUT}/{name}.png"
    img.save(path, "PNG")
    print(f"{name}: {img.size} {img.mode} title={ts}px lines={len(tag_lines)}")


def bg_cream(img):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, H], fill=CREAM)
    wash = Image.new("RGB", (W, H), CREAM)
    ImageDraw.Draw(wash).ellipse((W - 480, H - 340, W + 240, H + 260), fill=(0xE9, 0xF3, 0xEF))
    img.paste(wash.filter(ImageFilter.GaussianBlur(80)), (0, 0))
    ImageDraw.Draw(img).rectangle([0, H - 6, W, H], fill=PRIMARY)


def bg_green(img):
    top, bot = (0x35, 0x8B, 0x76), (0x1C, 0x53, 0x47)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((-200, -260, 600, 440), fill=(0x4E, 0xA8, 0x91))
    img.paste(Image.blend(img, glow.filter(ImageFilter.GaussianBlur(150)), 0.32), (0, 0))
    ImageDraw.Draw(img).rectangle([0, H - 6, W, H], fill=GOLD)


compose(bg_cream, PRIMARY, MEDIUM, GOLD, "A-cream")
compose(bg_green, (255, 255, 255), (0xD6, 0xEA, 0xE3), GOLD, "B-green")
