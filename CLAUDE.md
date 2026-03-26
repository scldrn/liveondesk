# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

liveondesk is a **macOS desktop application** (Swift/AppKit/SpriteKit) that transforms a user's pet photo into a personalized animated sprite that lives on the desktop, reacting to open windows and user activity. The pet is generated using AI (LoRA fine-tuning) so it visually resembles the user's specific animal.

This project is in the **planning stage** — `liveondesk_Idea.md` is the full product specification (in Spanish). No Xcode project or Swift source exists yet.

## Architecture

### Core macOS Stack
- **NSPanel** (AppKit) — transparent, borderless floating window with `canJoinAllSpaces` (visible on all Spaces), non-interactive (clicks pass through)
- **SpriteKit** — 2D physics engine for rendering, gravity, collision detection; target <5% CPU idle
- **CGWindowListCopyWindowInfo** (CoreGraphics) — polls window geometry every 500ms (2 Hz); no Screen Recording permission required, only reads geometry

### Window Classification Logic
Windows are classified by aspect ratio to determine pet behavior:
- **>2.5:1** wide → walking platform
- **~1:1** square → jump-on block
- **Small + corner** → hiding spot
- **Music app active** (detected by bundle ID, not audio API) → dance trigger
- **Dock edge** → running track

### Behavior State Machine
States: walking, jumping, sleeping (triggered by `CGEventSource` inactivity), dancing, sniffing, idle. Transitions driven by window events and context.

### AI Sprite Generation Pipeline
1. **Foreground isolation**: `VNGenerateForegroundInstanceMaskRequest` (Vision, on-device, free)
2. **Animal detection**: `VNRecognizeAnimalsRequest` (Vision) — cats/dogs auto, others manual
3. **Color extraction**: `CIAreaAverage` (Core Image) on isolated image
4. **LoRA training**: FLUX LoRA Fast Training via **fal.ai** (~$2-3, ~2min)
5. **Frame generation**: FLUX Kontext Pro via fal.ai (~$0.04/image); walking (8), idle (4), jump (4), sleep (4), dance (8), sniff (6)
6. **Video cycles**: Wan 2.1 Image-to-Video via fal.ai (~$0.05/sec) for smooth walk cycles
7. **Background removal**: Vision framework on each frame
8. **Spritesheet assembly**: frames + metadata file
9. **Storage**: local cache + Supabase

### Thought Bubble / LLM System
Context input: pet state, active app (via `NSWorkspace`), time of day, pet name/personality. Max 1 thought per 30 seconds.

LLM priority chain:
1. **Apple Foundation Models** (macOS 26+, Apple Intelligence required, on-device, free)
2. **MLX + Gemma 3 1B** (on-device fallback for older Macs with Apple Silicon, ~800MB)
3. **GPT-4o-mini** (cloud fallback, ~$14/month per 1,000 DAU)

### Backend
- **Supabase** (free tier) — auth, sprite storage (up to 500MB), cross-device config sync
- **Paddle** — payment processing for direct distribution (acts as Merchant of Record)
- **StoreKit 2** — in-app purchases for App Store distribution

## Recommended Build Order

Follow this sequence from `liveondesk_Idea.md`:
1. Transparent window + static sprite (validate the core visual experience first)
2. Window detection + basic physics (pet falls and walks on real windows)
3. Behavior state machine (all animation states)
4. Thought bubble with static phrases
5. Onboarding (photo → Vision processing → color-customized base sprite)
6. AI generation pipeline (LoRA + frame generation + spritesheet)
7. Dynamic thoughts (LLM integration)
8. Monetization (StoreKit 2, paywalls)
9. Distribution (App Store submission)

**Step 1 is the critical validation gate** — if the effect of a pet living on real windows doesn't generate the right emotional reaction in the first 10 testers, iterate before proceeding.

## Key Technical Constraints

- **Audio detection**: No reliable public API since macOS 15.4. Use bundle ID detection (Spotify, Apple Music, Tidal) instead of `kAudioDevicePropertyDeviceIsRunningSomewhere`
- **Screen Recording permission NOT required**: `CGWindowListCopyWindowInfo` only reads geometry, enabling straightforward App Store distribution
- **Sprite identity**: LoRA achieves ~90% fidelity; generate extra frames and filter by similarity score to discard bad outputs
- **Window transition physics**: Rapid window movements must animate (fall/land) rather than teleport the pet

## Reference: Competitive Architecture
BitTherapy (`CyrilCermak/bit-therapy` on GitHub) is the closest open-source reference — native Swift, SpriteKit, window physics, multi-monitor. Study its architecture for the desktop rendering layer.

## Distribution
- **Primary**: Mac App Store (no special permissions barrier)
- **Secondary**: Signed/notarized DMG + Sparkle for auto-updates
- **Requirement**: Apple Developer Program ($99/year)
