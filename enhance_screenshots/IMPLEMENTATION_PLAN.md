# Screenshot Styler — Implementation Plan

## Goal

Create a CLI tool that takes raw app screenshots (from Maestro/ADB or manual capture) and produces app store-ready images with:
- Dark blue-grey background
- Phone frame with rounded corners and shadow
- AI-generated marketing text (via Claude API) in the requested language
- Output meeting Google Play / App Store size requirements (1080×1920, 9:16, PNG)

The tool should work standalone and integrate into Fastlane metadata workflows.

---

## Context

- Apps: SafetyNet, Vigilo, ShowMyDay, LUDUS2030
- Screenshots come from Maestro flows (via `adb screencap`) or manual capture
- Fastlane is used for deployment — styled screenshots go into `fastlane/metadata/<locale>/images/phoneScreenshots/`
- Languages needed: Danish (`da`), English (`en`), potentially more
- Both Play Store and App Store listings need screenshots

---

## Phase 1: Core Python Script

**File:** `screenshot_styler.py`

### Task 1.1 — Image composition engine

Create the core styling function that takes a screenshot + text lines and produces the styled output.

Requirements:
- Input: any PNG/JPEG screenshot (any resolution)
- Output: 1080×1920 PNG (9:16 aspect ratio)
- Background: configurable color, default `rgb(55, 71, 90)`
- Phone frame: dark rounded rectangle with drop shadow
- Screenshot placed inside the phone frame, scaled to fit with aspect ratio preserved
- Rounded inner corners on the screenshot to match the frame
- White bold text centered above the phone frame
- Auto-adjust text position for 1, 2, or 3 lines of text
- Font: DejaVuSans-Bold (fallback chain for cross-platform)

Dependencies: `Pillow`

### Task 1.2 — Claude API text generation

Add a function that sends a screenshot to Claude's vision API and gets back a short marketing title.

Requirements:
- Use `anthropic` Python SDK
- Model: `claude-sonnet-4-20250514`
- Send screenshot as base64 image
- Prompt asks for 1-2 lines of text, max ~25 chars per line, title case
- Support language parameter (en, da, de, sv, no)
- Response parsed as JSON array of strings
- Graceful fallback if API fails (use filename-derived text)

Dependencies: `anthropic`

### Task 1.3 — CLI interface

Add argparse CLI with these options:

```
--input, -i     Input screenshot file or folder (required)
--output, -o    Output directory (required)
--lang, -l      Language code for AI text generation (default: en)
--text, -t      Custom text override (use \n for line breaks)
--bg-color      Background RGB as "R,G,B" (default: "55,71,90")
--config, -c    Path to JSON config file with per-screenshot text overrides
```

### Task 1.4 — Config file support

Support a JSON config file that maps screenshot filenames to specific text, so you don't regenerate text every time:

```json
{
  "defaults": {
    "bg_color": [55, 71, 90],
    "font_size": 52
  },
  "screenshots": {
    "incident_form.png": {
      "en": ["Record Incidents", "Quickly and Efficiently"],
      "da": ["Registrer en hændelse", "på få minutter"]
    },
    "documentation.png": {
      "en": ["Easy Access to", "Documents and Guides"],
      "da": ["Vejledninger og", "dokumentation lige", "ved hånden"]
    },
    "attachments.png": {
      "en": ["Attach Relevant Pictures"],
      "da": ["Vedhæft", "billeddokumentation"]
    },
    "survey.png": {
      "en": ["Answer Employee Surveys"],
      "da": ["Besvar spørgeskemaer", "og trivselsmålinger"]
    }
  }
}
```

When `--config` is provided:
1. Look up the screenshot filename in the config
2. Use the text for the requested `--lang`
3. If not found, fall back to Claude API generation
4. Offer a `--generate-config` flag that processes all screenshots and writes the config file (so you can review/edit the AI-generated text before committing)

---

## Phase 2: Fastlane Integration

### Task 2.1 — Fastlane metadata output structure

Add a `--fastlane` flag that outputs directly into Fastlane's expected folder structure:

```
fastlane/metadata/
├── da/
│   └── images/
│       └── phoneScreenshots/
│           ├── 1_incident_form_styled.png
│           ├── 2_documentation_styled.png
│           └── 3_attachments_styled.png
└── en-US/
    └── images/
        └── phoneScreenshots/
            ├── 1_incident_form_styled.png
            ├── 2_documentation_styled.png
            └── 3_attachments_styled.png
```

Requirements:
- `--fastlane <path>` points to the `fastlane/metadata` directory
- `--langs "en,da"` processes all specified languages in one run
- Files are numbered (prefix `1_`, `2_`, `3_`) to control ordering in the store
- Ordering comes from the config file (array order in `screenshots` section) or alphabetical

### Task 2.2 — Fastlane lane (optional)

Create a Fastlane lane `style_screenshots` that calls the Python script:

```ruby
# fastlane/Fastfile
lane :style_screenshots do
  sh("python3 ../tools/screenshot_styler.py " \
     "--input ../raw_screenshots " \
     "--fastlane ../fastlane/metadata " \
     "--config ../screenshot_config.json " \
     "--langs en,da")
end
```

---

## Phase 3: Maestro Pipeline Integration

### Task 3.1 — Post-capture hook

Create a wrapper script that runs after Maestro screenshot capture and automatically styles the results:

```bash
#!/bin/bash
# style_maestro_screenshots.sh
# Run after Maestro flow completes

MAESTRO_OUTPUT="$1"           # e.g., ./maestro_screenshots/
STYLED_OUTPUT="$2"            # e.g., ./styled_screenshots/
CONFIG="$3"                   # e.g., ./screenshot_config.json
LANGS="${4:-en,da}"

python3 screenshot_styler.py \
  --input "$MAESTRO_OUTPUT" \
  --output "$STYLED_OUTPUT" \
  --config "$CONFIG" \
  --langs "$LANGS"
```

### Task 3.2 — GitHub Actions step

Add a step to your existing CI/CD workflow that styles screenshots after Maestro captures them:

```yaml
- name: Style screenshots for store listing
  run: |
    pip install Pillow anthropic
    python3 tools/screenshot_styler.py \
      --input ./maestro_screenshots \
      --fastlane ./fastlane/metadata \
      --config ./screenshot_config.json \
      --langs en,da
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

---

## Phase 4: Multi-device & Store-specific Sizes

### Task 4.1 — Size presets

Add `--preset` flag for different store/device requirements:

| Preset | Dimensions | Aspect | Use |
|--------|-----------|--------|-----|
| `phone-portrait` | 1080×1920 | 9:16 | Default, Play Store phone |
| `phone-landscape` | 1920×1080 | 16:9 | Landscape screenshots |
| `iphone-6.9` | 1320×2868 | ~9:19.5 | iPhone 16 Pro Max (App Store) |
| `iphone-6.5` | 1242×2688 | ~9:19.5 | iPhone 11 Pro Max (App Store) |
| `ipad-13` | 2064×2752 | ~3:4 | iPad Pro (App Store) |
| `tablet-7` | 1080×1920 | 9:16 | Android 7" tablet |
| `tablet-10` | 1200×1920 | ~10:16 | Android 10" tablet |

### Task 4.2 — Batch multi-preset

Support `--presets "phone-portrait,iphone-6.9"` to generate multiple sizes per screenshot in one run.

---

## Project Structure

```
screenshot-styler/
├── screenshot_styler.py          # Main CLI tool
├── screenshot_config.json        # Per-app text config (committed, editable)
├── requirements.txt              # Pillow, anthropic
├── README.md                     # Usage docs
├── tests/
│   ├── test_styler.py            # Unit tests for image composition
│   └── fixtures/                 # Test screenshots
└── examples/
    ├── raw/                      # Example raw screenshots
    ├── styled/                   # Example styled output
    └── config.json               # Example config
```

---

## Implementation Order

| Priority | Task | Effort | Notes |
|----------|------|--------|-------|
| 🔴 P0 | 1.1 Image composition | ~1hr | Core engine, already prototyped |
| 🔴 P0 | 1.2 Claude API text gen | ~30min | Straightforward API call |
| 🔴 P0 | 1.3 CLI interface | ~30min | Argparse wrapper |
| 🟡 P1 | 1.4 Config file support | ~1hr | JSON config + `--generate-config` |
| 🟡 P1 | 2.1 Fastlane output structure | ~1hr | Directory layout + numbering |
| 🟢 P2 | 3.1 Post-capture hook | ~30min | Shell wrapper script |
| 🟢 P2 | 3.2 GitHub Actions step | ~30min | CI integration |
| 🟢 P2 | 2.2 Fastlane lane | ~15min | Ruby lane calling Python |
| 🔵 P3 | 4.1 Size presets | ~1hr | Multi-device support |
| 🔵 P3 | 4.2 Batch multi-preset | ~30min | Loop over presets |

**Total estimated effort: ~7 hours**

---

## Quick Start for Claude Code

```bash
# In your project directory:
claude "Read IMPLEMENTATION_PLAN.md and implement Phase 1 (Tasks 1.1-1.4). 
Create screenshot_styler.py with the image composition engine, Claude API 
text generation, CLI interface, and config file support. Use the existing 
prototype from the conversation as reference for the styling logic. 
Write unit tests for the image composition."
```

### Follow-up prompts:

```bash
# Phase 2:
claude "Read IMPLEMENTATION_PLAN.md and implement Phase 2 (Tasks 2.1-2.2). 
Add --fastlane and --langs flags to screenshot_styler.py that output into 
Fastlane's metadata directory structure."

# Phase 3:
claude "Read IMPLEMENTATION_PLAN.md and implement Phase 3 (Tasks 3.1-3.2). 
Create the Maestro post-capture hook script and GitHub Actions workflow step."

# Phase 4:
claude "Read IMPLEMENTATION_PLAN.md and implement Phase 4 (Tasks 4.1-4.2). 
Add size presets for iPhone/iPad/tablet and batch multi-preset support."
```

---

## Validation Checklist

After each phase, verify:

- [ ] Output is PNG, 1080×1920, ≤8MB
- [ ] Text is centered and readable
- [ ] Phone frame has rounded corners and shadow
- [ ] Screenshot scales correctly regardless of input resolution
- [ ] Danish characters (æ, ø, å) render correctly
- [ ] `--config` file overrides AI generation
- [ ] `--generate-config` creates editable config from AI output
- [ ] Fastlane directory structure matches `deliver`/`supply` expectations
- [ ] Works in CI (headless, no display)
