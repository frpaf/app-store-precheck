---
name: app-store-screenshots
version: 1.0.0
description: Explore a mobile app using agent-device, capture unique screenshots, generate marketing captions, and produce styled store-ready images with phone frames and text overlays.
triggers:
  - app store screenshots
  - play store listing images
  - screenshot captions
  - feature graphics text
  - marketing screenshots
  - store listing screenshots
  - app screenshots with captions
  - automated store assets
tools:
  - bash
  - read
---

# App Store Screenshots & Caption Generator

Explore a mobile app using `agent-device`, capture unique screenshots of key screens, generate marketing captions, and produce styled store-ready images with phone frames and text overlays.

## Prerequisites

- `agent-device` CLI installed (`npm install -g agent-device`)
- iOS Simulator or Android Emulator running with the target app installed
- Python 3 + Pillow (`pip install Pillow`)

## IMPORTANT: Complete All 4 Phases

You MUST execute all four phases in order. Do NOT stop after capturing screenshots or generating captions. The final deliverable is styled store-ready images, not raw screenshots.

1. **Phase 1 — App Exploration**: Open app, navigate, capture 5-8 unique screenshots
2. **Phase 2 — Caption Generation**: Write marketing captions for each screenshot
3. **Phase 3 — Output Organization**: Create `captions.json`, validate lengths, generate summary
4. **Phase 4 — Screenshot Styling**: Run `screenshot_styler.py` to produce final store-ready images with phone frames and marketing text overlays. This is the final step — do not skip it.

## Workflow

### Phase 1 — App Exploration

Use `agent-device` to systematically explore the app and capture unique screens.

#### Exploration Strategy

1. **Open the app**: `agent-device open <bundle-id> --platform <ios|android>`
2. **Take initial snapshot**: `agent-device snapshot -i` (interactive mode shows element IDs)
3. **Screenshot the home screen**: `agent-device screenshot <output_dir>/01_home.png`
4. **Navigate systematically**:
   - Explore tab bar items first (bottom navigation)
   - Go one level deep into each major section
   - Look for unique screen types (lists, details, forms, charts, settings)
5. **After each navigation**: Always `snapshot -i` then `screenshot`
6. **Skip duplicates**: Compare accessibility tree structure — if >80% similar node types, skip
7. **Aim for 5-8 unique screens** covering the app's key features

#### Exploration Commands

```bash
# Open app
agent-device open com.example.app --platform ios

# Take snapshot (interactive — shows clickable elements)
agent-device snapshot -i

# Capture screenshot
agent-device screenshot screenshots/01_home.png

# Navigate by clicking element
agent-device click @e5

# Scroll down to reveal more content
agent-device scroll down

# Search for specific UI elements
agent-device find "settings"

# Go back
agent-device key back

# Close app when done
agent-device close
```

#### Login Screen Handling

After opening the app, if the first screen is a login/auth gate:

1. **Detect**: Look for text fields labeled "email", "username", "password", or sign-in buttons in the snapshot
2. **Prompt the user**: Ask for their username/email and password — do not guess or skip
3. **Enter credentials**: Use `agent-device fill @eN "username"` and `agent-device fill @eN "password"` then tap the sign-in button
4. **Verify**: Take a snapshot after login to confirm you're past the auth screen
5. **If user declines**: Document that auth is required and capture only pre-login screens

#### Deduplication Approach

Before capturing a screenshot, compare the current screen's accessibility tree with previously captured screens:
- Count node types (buttons, text fields, images, lists)
- If the structure matches a previous screen by >80%, skip it
- Focus on screens that show distinct features or content types

### Phase 2 — Caption Generation

For each captured screenshot, generate marketing captions in both store formats.

#### Caption Formats

| Store | Field | Max Length |
|-------|-------|-----------|
| Play Store | Short caption | 80 chars |
| Play Store | Long caption | 200 chars |
| App Store | Caption | 70 chars |
| App Store | Subtitle | 30 chars |

#### Caption Writing Rules

1. **Benefit-first**: Lead with what the user gains, not what the feature does
2. **Active voice**: "Track your goals" not "Goals can be tracked"
3. **Be specific**: "Save 2 hours weekly" not "Save time"
4. **Vary patterns**: Don't start every caption the same way
5. **Match tone to category**: Professional for business, encouraging for health, etc.
6. **No technical jargon**: Speak to end users, not developers
7. **Include action verbs**: Track, Discover, Manage, Create, Monitor, Explore

#### Caption Examples by Screen Type

| Screen Type | Good Caption | Bad Caption |
|-------------|-------------|-------------|
| Dashboard | "Your day at a glance" | "Main screen" |
| List view | "Find anything in seconds" | "List of items" |
| Detail view | "Every detail, one tap away" | "Item details" |
| Form/Input | "Get started in under a minute" | "Input form" |
| Chart/Stats | "Watch your progress grow" | "Statistics page" |
| Settings | "Make it yours" | "Settings screen" |
| Map view | "Discover what's nearby" | "Map" |
| Profile | "Your personal hub" | "Profile page" |

#### Tone Guide by App Category

| Category | Tone | Example |
|----------|------|---------|
| Business/Productivity | Professional, efficient | "Streamline your workflow" |
| Health/Fitness | Encouraging, motivating | "Every step counts" |
| Education | Engaging, empowering | "Learn at your own pace" |
| Social | Warm, connected | "Stay close to what matters" |
| Finance | Trustworthy, clear | "Your money, crystal clear" |
| Utility | Simple, direct | "Get it done, faster" |

### Phase 3 — Output Organization

Run the output organizer to validate and structure the results.

```bash
python3 skills/app-store-screenshots/scripts/organize_output.py <output_dir> <captions.json>
```

This produces:
- Validated `captions.json` with warnings for any length violations
- Human-readable `captions_summary.md` with character counts
- Summary report of screenshot count, platform, and any issues

#### Output JSON Structure

```json
{
  "app_name": "MyApp",
  "platform": "ios",
  "generated_at": "2026-02-22T12:00:00Z",
  "screenshots": [
    {
      "filename": "01_home.png",
      "screen_type": "dashboard",
      "description": "Main dashboard showing task overview",
      "captions": {
        "play_store": {
          "short": "Your day at a glance",
          "long": "See all your tasks, deadlines, and progress in one beautiful dashboard"
        },
        "app_store": {
          "caption": "Your day at a glance",
          "subtitle": "Real-time dashboard"
        }
      }
    }
  ]
}
```

### Phase 4 — Screenshot Styling (MANDATORY — Do Not Skip)

**Immediately after Phase 3**, run the screenshot styler to produce the final store-ready images. This is the main deliverable — raw screenshots are not suitable for store listings.

Run this command, replacing the paths with the actual directories used in the previous phases:

```bash
python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
  --input <screenshots_dir> \
  --output <screenshots_dir>/styled \
  --captions-json <screenshots_dir>/captions.json
```

The styled images are saved to `<screenshots_dir>/styled/` alongside the raw captures.

#### Additional Options

```bash
# With a specific language for text overlay
python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
  --input <screenshots_dir> \
  --output <screenshots_dir>/styled \
  --captions-json <screenshots_dir>/captions.json \
  --lang da

# With custom background color
python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
  --input <screenshots_dir> \
  --output <screenshots_dir>/styled \
  --captions-json <screenshots_dir>/captions.json \
  --bg-color "25,25,112"

# Generate for a specific device preset (e.g., App Store iPhone)
python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
  --input <screenshots_dir> \
  --output <screenshots_dir>/styled_iphone \
  --captions-json <screenshots_dir>/captions.json \
  --preset iphone-6.9
```

#### What the Styler Does

For each raw screenshot it produces a store-ready image with:
- **Background**: Configurable solid color (default: dark blue-grey `rgb(55, 71, 90)`)
- **Phone frame**: Dark rounded rectangle with drop shadow
- **Marketing text**: Centered above the phone frame, pulled from `captions.json`
- **Output size**: Matches the selected preset (default: 1080x1920 for Play Store)

#### Text Source Priority

The styler resolves marketing text in this order:
1. **Config file** (`--config`) — per-screenshot text overrides you've manually edited
2. **Captions JSON** (`--captions-json`) — uses Play Store short caption or App Store caption from Phase 3
3. **Manual text** (`--text`) — single text applied to all screenshots
4. **Claude API** — sends each screenshot to Claude vision API to generate text (requires `ANTHROPIC_API_KEY`)
5. **Filename fallback** — derives text from the screenshot filename

#### Config File for Repeatable Builds

Generate a config file from AI analysis, then edit it before committing:

```bash
# Generate config (review and edit the text before using)
python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
  --input <screenshots_dir> \
  --output <styled_output_dir> \
  --generate-config screenshot_config.json --lang en

# Use the edited config for consistent builds
python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
  --input <screenshots_dir> \
  --output <styled_output_dir> \
  --config screenshot_config.json --lang en
```

Config file format:
```json
{
  "defaults": {
    "bg_color": [55, 71, 90],
    "font_size": 52
  },
  "screenshots": {
    "01_home.png": {
      "en": ["Track Every Task", "At a Glance"],
      "da": ["Overblik over", "alle opgaver"]
    },
    "02_settings.png": {
      "en": ["Make It Yours"],
      "da": ["Tilpas det til dig"]
    }
  }
}
```

#### Size Presets

| Preset | Dimensions | Use |
|--------|-----------|-----|
| `phone-portrait` | 1080 x 1920 | Default, Play Store phone |
| `phone-landscape` | 1920 x 1080 | Landscape screenshots |
| `iphone-6.9` | 1320 x 2868 | iPhone 16 Pro Max (App Store) |
| `iphone-6.5` | 1242 x 2688 | iPhone 11 Pro Max (App Store) |
| `ipad-13` | 2064 x 2752 | iPad Pro (App Store) |
| `tablet-7` | 1080 x 1920 | Android 7" tablet |
| `tablet-10` | 1200 x 1920 | Android 10" tablet |

To generate multiple sizes, run the styler once per preset:

```bash
for preset in phone-portrait iphone-6.9; do
  python3 skills/app-store-screenshots/scripts/screenshot_styler.py \
    --input screenshots/ --output "styled_${preset}/" \
    --captions-json output/captions.json --preset "$preset"
done
```

#### Dependencies

- Python 3
- Pillow (`pip install Pillow`)
- `anthropic` SDK (optional — only needed if no config/captions provided)

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Login/auth screen | If the app opens to a login screen that blocks exploration, **prompt the user** for credentials (username and password) before proceeding. Use `agent-device find "email"` or `agent-device find "username"` to locate input fields, then `agent-device fill @eN "value"` to enter credentials. After login, continue exploration normally. If the user declines to provide credentials, note in output that the app requires auth and only the login screen could be captured. Capture the login screen only if the login UI is a key feature worth showcasing. |
| Permission dialogs | Dismiss and continue. Don't capture as a marketing screenshot. |
| Loading states | Wait for content to load before capturing. Use `agent-device snapshot` to verify. |
| Empty states | Capture only if the empty state has good onboarding UX worth showcasing. |
| Dark mode | Note if app supports dark mode. Capture separately if user requests. |
| Landscape screens | Note if app has landscape features. Capture if significantly different from portrait. |
| Onboarding flow | Capture 1-2 best onboarding screens if they showcase value proposition. |
| Error states | Skip — never use error states as marketing screenshots. |

## Quick Reference

See `references/agent-device-commands.md` for the full agent-device command reference.
See `references/store-listing-specs.md` for screenshot dimensions and store requirements.

## $ARGUMENTS

```
/app-store-screenshots <bundle-id> --platform <ios|android> [--count 5-8] [--store play|apple|both]
```
