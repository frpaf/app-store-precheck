#!/usr/bin/env python3
"""
Screenshot Styler - Automatically creates app store-ready screenshots
with phone frames and AI-generated descriptive text.

Usage:
    python screenshot_styler.py --input ./screenshots --output ./styled
    python screenshot_styler.py --input ./screenshots --output ./styled --lang da
    python screenshot_styler.py --input ./screenshots --output ./styled --lang en
    python screenshot_styler.py --input ./shot.png --output ./styled --text "Custom Title"
"""

import os
import sys
import json
import base64
import argparse
import subprocess
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "--break-system-packages", "-q"])
    from PIL import Image, ImageDraw, ImageFont, ImageFilter

try:
    import anthropic
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "anthropic", "--break-system-packages", "-q"])
    import anthropic


# ─── Configuration ───────────────────────────────────────────────────────────

CANVAS_WIDTH = 1080
CANVAS_HEIGHT = 1920
BG_COLOR = (55, 71, 90)        # Dark blue-grey
FRAME_COLOR = (30, 30, 30)     # Phone frame
TEXT_COLOR = (255, 255, 255)    # White text
FONT_SIZE = 52
LINE_SPACING = 68
PHONE_BORDER = 16
CORNER_RADIUS = 40
SHADOW_OFFSET = 8
SHADOW_BLUR = 12
TEXT_Y_START = 80
PHONE_BOTTOM_MARGIN = 80
MODEL = "claude-sonnet-4-20250514"


# ─── Drawing Helpers ─────────────────────────────────────────────────────────

def rounded_rect(draw, xy, radius, fill):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=fill)


def get_font(size=FONT_SIZE):
    """Find and return a bold font."""
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "C:\\Windows\\Fonts\\arialbd.ttf",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            return ImageFont.truetype(fp, size)
    return ImageFont.load_default()


# ─── Text Generation ─────────────────────────────────────────────────────────

def generate_text_for_screenshot(image_path: str, lang: str = "en") -> list[str]:
    """Use Claude to analyze a screenshot and generate a short descriptive title."""
    
    client = anthropic.Anthropic()
    
    with open(image_path, "rb") as f:
        image_data = base64.standard_b64encode(f.read()).decode("utf-8")
    
    ext = Path(image_path).suffix.lower()
    media_type = "image/png" if ext == ".png" else "image/jpeg"
    
    lang_instruction = {
        "en": "in English",
        "da": "in Danish (Dansk)",
        "de": "in German (Deutsch)",
        "sv": "in Swedish (Svenska)",
        "no": "in Norwegian (Norsk)",
    }.get(lang, f"in {lang}")
    
    response = client.messages.create(
        model=MODEL,
        max_tokens=200,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": media_type,
                        "data": image_data,
                    },
                },
                {
                    "type": "text",
                    "text": f"""Look at this mobile app screenshot and generate a short, catchy marketing title {lang_instruction} that describes what the user can do on this screen.

Rules:
- Maximum 2 lines of text
- Each line should be max 25 characters
- The text should be suitable for an app store listing
- Focus on the user benefit/action, not technical details
- Use title case

Return ONLY a JSON array of strings, one per line. Example: ["Record Incidents", "Quickly and Efficiently"]"""
                }
            ],
        }],
    )
    
    text = response.content[0].text.strip()
    # Parse JSON array from response
    try:
        lines = json.loads(text)
        if isinstance(lines, list):
            return [str(l) for l in lines]
    except json.JSONDecodeError:
        pass
    
    # Fallback: split by newlines
    return [l.strip().strip('"').strip("'") for l in text.split("\n") if l.strip()]


# ─── Image Composition ───────────────────────────────────────────────────────

def create_styled_screenshot(
    screenshot_path: str,
    output_path: str,
    text_lines: list[str],
    bg_color: tuple = BG_COLOR,
):
    """Create a styled app store screenshot with phone frame and text."""
    
    screenshot = Image.open(screenshot_path)
    screen_aspect = screenshot.width / screenshot.height
    
    canvas = Image.new('RGB', (CANVAS_WIDTH, CANVAS_HEIGHT), bg_color)
    draw = ImageDraw.Draw(canvas)
    font = get_font()
    
    # ── Draw text ──
    num_lines = len(text_lines)
    # Adjust start position for 3+ lines
    y_start = TEXT_Y_START if num_lines <= 2 else 60
    
    for i, line in enumerate(text_lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        tx = (CANVAS_WIDTH - tw) // 2
        ty = y_start + i * LINE_SPACING
        draw.text((tx, ty), line, fill=TEXT_COLOR, font=font)
    
    # ── Calculate phone dimensions ──
    phone_top = y_start + num_lines * LINE_SPACING + 60
    phone_bottom = CANVAS_HEIGHT - PHONE_BOTTOM_MARGIN
    phone_height = phone_bottom - phone_top
    
    phone_screen_h = phone_height - 2 * PHONE_BORDER
    phone_screen_w = int(phone_screen_h * screen_aspect)
    phone_frame_w = phone_screen_w + 2 * PHONE_BORDER
    phone_frame_h = phone_height
    phone_x = (CANVAS_WIDTH - phone_frame_w) // 2
    phone_y = phone_top
    
    # ── Draw shadow ──
    shadow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    rounded_rect(shadow_draw,
        (phone_x + SHADOW_OFFSET, phone_y + SHADOW_OFFSET,
         phone_x + phone_frame_w + SHADOW_OFFSET,
         phone_y + phone_frame_h + SHADOW_OFFSET),
        CORNER_RADIUS, (0, 0, 0, 80))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    canvas.paste(
        Image.composite(
            shadow,
            Image.new('RGBA', canvas.size, (0, 0, 0, 0)),
            shadow
        ).convert('RGB'),
        mask=shadow.split()[3]
    )
    
    # ── Draw phone frame ──
    draw = ImageDraw.Draw(canvas)  # Re-create after paste
    rounded_rect(draw,
        (phone_x, phone_y, phone_x + phone_frame_w, phone_y + phone_frame_h),
        CORNER_RADIUS, FRAME_COLOR)
    
    # ── Place screenshot ──
    screen_x = phone_x + PHONE_BORDER
    screen_y = phone_y + PHONE_BORDER
    resized = screenshot.resize((phone_screen_w, phone_screen_h), Image.LANCZOS)
    
    # Rounded corners mask
    mask = Image.new('L', (phone_screen_w, phone_screen_h), 0)
    mask_draw = ImageDraw.Draw(mask)
    inner_r = max(CORNER_RADIUS - PHONE_BORDER, 8)
    rounded_rect(mask_draw, (0, 0, phone_screen_w, phone_screen_h), inner_r, 255)
    
    canvas.paste(resized, (screen_x, screen_y), mask)
    
    # ── Save ──
    canvas.save(output_path, 'PNG')
    size_kb = os.path.getsize(output_path) / 1024
    print(f"  ✓ Saved: {output_path} ({CANVAS_WIDTH}x{CANVAS_HEIGHT}, {size_kb:.0f} KB)")
    
    return output_path


# ─── Main ────────────────────────────────────────────────────────────────────

def process_folder(input_path: str, output_dir: str, lang: str = "en", custom_text: str = None):
    """Process all screenshots in a folder."""
    
    os.makedirs(output_dir, exist_ok=True)
    input_path = Path(input_path)
    
    # Single file or folder?
    if input_path.is_file():
        files = [input_path]
    else:
        files = sorted([
            f for f in input_path.iterdir()
            if f.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp')
        ])
    
    if not files:
        print(f"No image files found in {input_path}")
        return
    
    print(f"\n📱 Processing {len(files)} screenshot(s)...\n")
    
    for i, filepath in enumerate(files, 1):
        print(f"[{i}/{len(files)}] {filepath.name}")
        
        # Generate or use custom text
        if custom_text:
            lines = [l.strip() for l in custom_text.split("\\n")]
        else:
            print(f"  🤖 Generating text ({lang})...")
            try:
                lines = generate_text_for_screenshot(str(filepath), lang)
            except Exception as e:
                print(f"  ⚠ API error: {e}")
                print(f"  Using filename as fallback")
                lines = [filepath.stem.replace("_", " ").replace("-", " ").title()]
        
        print(f"  📝 Text: {' / '.join(lines)}")
        
        output_name = f"{filepath.stem}_styled.png"
        output_path = str(Path(output_dir) / output_name)
        
        create_styled_screenshot(str(filepath), output_path, lines)
    
    print(f"\n✅ Done! {len(files)} styled screenshot(s) saved to {output_dir}/\n")


def main():
    parser = argparse.ArgumentParser(
        description="Create app store-ready screenshots with phone frames and auto-generated text"
    )
    parser.add_argument("--input", "-i", required=True,
                        help="Input screenshot file or folder")
    parser.add_argument("--output", "-o", required=True,
                        help="Output directory for styled screenshots")
    parser.add_argument("--lang", "-l", default="en",
                        help="Language for generated text (en, da, de, sv, no)")
    parser.add_argument("--text", "-t", default=None,
                        help="Custom text (use \\n for line breaks). Overrides AI generation.")
    parser.add_argument("--bg-color", default=None,
                        help="Background color as R,G,B (e.g., '55,71,90')")
    
    args = parser.parse_args()
    
    if args.bg_color:
        global BG_COLOR
        BG_COLOR = tuple(int(x) for x in args.bg_color.split(","))
    
    process_folder(args.input, args.output, args.lang, args.text)


if __name__ == "__main__":
    main()
