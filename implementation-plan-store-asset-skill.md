# Implementation Plan: App Store Asset Skills

## Overview

Add two new skills to the `store-deploy-skills` Claude Code plugin:
1. **google-play-icon** — Generate Play Store compliant 512×512 icons from source images
2. **app-store-screenshots** — Explore apps with `agent-device`, capture screenshots, generate marketing captions

**Repo**: `store-deploy-skills` at `skills/`
**Plugin manifest**: `.claude-plugin/plugin.json`

---

## Phase 1: google-play-icon Skill

### Step 1.1 — Create skill directory structure

```bash
mkdir -p skills/google-play-icon/scripts
```

### Step 1.2 — Create `skills/google-play-icon/SKILL.md`

Frontmatter must follow existing plugin conventions (`user-invocable`, `allowed-tools`, etc.).

```yaml
---
name: google-play-icon
description: >
  Generate Google Play Store compliant app icons from source images. Use when user wants
  to create, convert, resize, or prepare an app icon for Google Play Store upload. Triggers
  on mentions of Play Store icon, Android app icon, adaptive icon foreground, app store icon,
  icon specifications, or background color replacement for icons.
argument-hint: "<source_image> [--bg-color white|navy|custom R G B] [--no-replace]"
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read
---
```

Body should include:
- Google Play icon specs (512×512, 32-bit PNG, sRGB, max 1MB, full square, no rounded corners, no shadows)
- Workflow: inspect source → ask about background color → run `scripts/generate_icon.py` → verify → present
- Design guidelines from Google (full-bleed vs keyline grid placement)
- Edge cases (already correct size, oversized output, small source warning)
- `$ARGUMENTS` block at bottom for Claude Code argument passing

### Step 1.3 — Create `skills/google-play-icon/scripts/generate_icon.py`

Python script using Pillow. Core functionality:

- **Input**: source image path, output path, options
- **Auto-detect background color** by sampling edge pixels (numpy)
- **Replace background**: swap detected/specified color within threshold to new color
- **Resize** to 512×512 with LANCZOS
- **Output** as 32-bit PNG (RGBA), optimize if >1MB
- **CLI interface** with argparse:
  - `--bg-color R G B` (default: 255 255 255)
  - `--replace-color R G B` (default: auto-detect)
  - `--threshold N` (default: 15)
  - `--no-replace` flag

Dependencies: `Pillow`, `numpy` (both commonly available)

### Step 1.4 — Test the script

```bash
# Test with an adaptive icon foreground (black background → white)
python3 skills/google-play-icon/scripts/generate_icon.py \
  path/to/foreground.png output_icon.png --bg-color 255 255 255

# Test with --no-replace for full-bleed artwork
python3 skills/google-play-icon/scripts/generate_icon.py \
  path/to/artwork.png output_icon.png --no-replace

# Verify output
file output_icon.png   # Should be PNG
identify output_icon.png  # Should be 512x512 (if imagemagick available)
ls -la output_icon.png  # Should be < 1MB
```

---

## Phase 2: app-store-screenshots Skill

### Step 2.1 — Create skill directory structure

```bash
mkdir -p skills/app-store-screenshots/scripts
mkdir -p skills/app-store-screenshots/references
```

### Step 2.2 — Create `skills/app-store-screenshots/SKILL.md`

Frontmatter:

```yaml
---
name: app-store-screenshots
description: >
  Explore a mobile app using agent-device, capture unique screenshots, and generate app store
  marketing captions for each screen. Use when user wants Play Store or App Store listing
  screenshots with captions, marketing copy from app screens, automated store asset creation,
  or feature descriptions from screenshots. Triggers on mentions of app store screenshots,
  Play Store listing images, screenshot captions, feature graphics text, or marketing screenshots.
argument-hint: "<bundle-id> --platform <ios|android> [--count 5-8] [--store play|apple|both]"
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read
---
```

Body should cover three phases:

**Phase 1 — Exploration**: agent-device workflow (open → snapshot -i → screenshot → click → repeat).
Include exploration strategy (tabs first, one level deep, skip duplicates, aim for 5-8 screens)
and deduplication approach (compare accessibility tree structure).

**Phase 2 — Caption Generation**: For each screenshot, identify screen type and key value proposition.
Generate captions in both formats:
- Play Store: short (≤80 chars) + long (≤200 chars)
- App Store: caption (≤70 chars) + subtitle (≤30 chars)

Include caption writing rules (benefit-first, active voice, specific, varied patterns,
tone matched to app category).

**Phase 3 — Output**: Run `scripts/organize_output.py` to validate and structure output
as `captions.json` + `captions_summary.md`.

Edge cases: login screens, permission dialogs, loading states, empty states, landscape/dark mode.

### Step 2.3 — Create `skills/app-store-screenshots/references/agent-device-commands.md`

Quick reference covering:
- App lifecycle: `open`, `close`
- Snapshots: `snapshot`, `snapshot -i`, `screenshot`
- Interactions: `click @eN`, `fill @eN "text"`, `scroll`, `type`, `get`
- Semantic search: `find "description"`
- Recording: `record`, `replay`, `replay --update`
- Tips: always snapshot after actions, use `-i` flag, descriptive filenames, fallback to coordinates

### Step 2.4 — Create `skills/app-store-screenshots/references/store-listing-specs.md`

Reference data:
- Play Store screenshot specs (dimensions, formats, limits)
- App Store screenshot specs (device sizes, formats)
- Caption best practices table by screen type (dashboard, list, detail, form, chart, settings, map, etc.)
- Tone guide table by app category (business, health, education, social, finance, utility)

### Step 2.5 — Create `skills/app-store-screenshots/scripts/organize_output.py`

Python script that:
- Reads `captions.json` input
- Validates all caption lengths against store limits (warns on violations)
- Generates human-readable `captions_summary.md` with char counts
- Reports summary (screenshot count, app name, platform, any warnings)

CLI: `python3 organize_output.py <output_dir> <captions.json>`

### Step 2.6 — Test the skill (requires agent-device + simulator)

```bash
# Install agent-device
npm install -g agent-device

# Start iOS simulator or Android emulator with target app

# Test exploration flow
agent-device open com.example.app --platform ios
agent-device snapshot -i
agent-device screenshot test_screenshots/01_home.png
agent-device close

# Test output organizer with sample data
cat > /tmp/test_captions.json << 'EOF'
{
  "app_name": "TestApp",
  "platform": "ios",
  "generated_at": "2026-02-22T12:00:00Z",
  "screenshots": [
    {
      "filename": "01_home.png",
      "screen_type": "dashboard",
      "description": "Main dashboard",
      "captions": {
        "play_store": {"short": "Track every task at a glance", "long": "Your real-time dashboard shows active tasks and progress"},
        "app_store": {"caption": "Track every task at a glance", "subtitle": "Real-time dashboard"}
      }
    }
  ]
}
EOF
python3 skills/app-store-screenshots/scripts/organize_output.py /tmp/test_output /tmp/test_captions.json
```

---

## Phase 3: Update Plugin Manifest

### Step 3.1 — Update `.claude-plugin/plugin.json`

```json
{
  "name": "store-deploy-skills",
  "description": "Skills to deploy mobile applications, generate app store assets, and automate store listing workflows for iOS and Android",
  "version": "1.1.0",
  "author": {
    "name": "frpaf"
  },
  "repository": "https://github.com/frpaf/store-deploy-skills",
  "keywords": [
    "mobile", "deployment", "ios", "android", "expo", "flutter",
    "play-store", "app-store", "icon", "screenshots", "marketing", "agent-device"
  ]
}
```

Changes from v1.0.0:
- Version bump to 1.1.0
- Updated description to cover asset generation
- Added keywords: play-store, app-store, icon, screenshots, marketing, agent-device

---

## Phase 4: Commit & Push

```bash
cd /path/to/store-deploy-skills

git add skills/google-play-icon/ skills/app-store-screenshots/ .claude-plugin/plugin.json
git commit -m "feat: add google-play-icon and app-store-screenshots skills

- google-play-icon: Generate 512x512 Play Store icons from source images
  with auto background detection and replacement
- app-store-screenshots: Explore apps via agent-device, capture unique
  screens, generate Play Store and App Store marketing captions
- Bump plugin version to 1.1.0"

git push origin master
```

---

## Phase 5: Verify Installation

After pushing, test that the plugin installs correctly in Claude Code:

```bash
# In a project directory
claude
> /plugin install store-deploy-skills@frpaf
> /google-play-icon path/to/icon.png --bg-color 255 255 255
> /app-store-screenshots com.eg.safetynet --platform android
```

---

## File Inventory

```
store-deploy-skills/
├── .claude-plugin/
│   └── plugin.json                                    # UPDATED (v1.0.0 → v1.1.0)
├── skills/
│   ├── google-play-icon/                              # NEW
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── generate_icon.py
│   ├── app-store-screenshots/                         # NEW
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── agent-device-commands.md
│   │   │   └── store-listing-specs.md
│   │   └── scripts/
│   │       └── organize_output.py
│   ├── changelog/                                     # EXISTING
│   ├── deploy/                                        # EXISTING
│   ├── mobile-deployment/                             # EXISTING
│   ├── setup/                                         # EXISTING
│   ├── status/                                        # EXISTING
│   └── version/                                       # EXISTING
└── vault-migration-updates.md                         # EXISTING
```

## Dependencies

| Skill | Dependency | Required For |
|---|---|---|
| google-play-icon | Python 3 + Pillow + numpy | Image processing |
| app-store-screenshots | agent-device CLI (`npm i -g agent-device`) | App exploration |
| app-store-screenshots | Python 3 | Output organization |
| app-store-screenshots | iOS Simulator or Android Emulator | Running target app |
