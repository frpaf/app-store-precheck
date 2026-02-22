---
name: app-store-screenshots
version: 1.0.0
description: Explore a mobile app using agent-device, capture unique screenshots, and generate app store marketing captions for each screen.
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

Explore a mobile app using `agent-device`, capture unique screenshots of key screens, and generate marketing captions for Play Store and App Store listings.

## Prerequisites

- `agent-device` CLI installed (`npm install -g agent-device`)
- iOS Simulator or Android Emulator running with the target app installed
- Python 3 for output organization

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

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Login/auth screen | Skip unless login UI is a key feature. Note in output if auth is required. |
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
