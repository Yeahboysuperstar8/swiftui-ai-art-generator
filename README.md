# AI Art Generator (SwiftUI)

A SwiftUI iOS/iPadOS application that generates AI artwork using the [Pollinations.ai](https://pollinations.ai) image generation API (`flux` model). Built with full prompt customization, seed locking, resolution scaling, and a built-in custom pull-out QWERTY keyboard.

## Features

- **Prompt & Negative Prompt Controls:** Define what you want to see and specify elements to exclude from the final image.
- **Built-In Art Style Presets:** Quickly append curated style modifiers including *Hyper Realistic*, *Photorealistic*, *Anime*, *Furry*, *Watercolor*, *Cyberpunk*, and *Oil Painting*, or use *None* for raw prompts.
- **Aspect Ratio & Resolution Scaling:** Switch between **Square (1:1)**, **Portrait (3:4)**, and **Landscape (4:3)** with adjustable resolution from `256px` up to `1024px`.
- **Seed Management:** Randomize seeds with one tap or lock a seed to reproduce consistent results.
- **Privacy & Generation Toggles:**
  - **AI Prompt Enhancement:** Let AI expand your prompt with extra detail or keep your exact wording.
  - **Safe Mode Filter:** Toggle Pollinations' server-side content filter.
  - **Private Generation:** Keep generated images off public feeds.
- **Custom Pull-Out QWERTY Keyboard:** Integrated on-screen keyboard with shift/caps, numbers/symbols layout, clipboard paste support, and field switching.
- **Save & Share:** Save generated artwork directly to the iOS Photo Library or share via the native iOS Share Sheet.
- **Local API Key Storage:** Securely saves your Pollinations Secret Key (`sk_...`) on-device via `@AppStorage`—no need to edit the source code.

## Requirements

- iOS 16.0+ / iPadOS 16.0+
- Swift 5.7+ / SwiftUI
- A Pollinations API Secret Key (`sk_...`) from [enter.pollinations.ai](https://pollinations.ai)

## Setup & Usage

1. Add `ContentView.swift` to your Xcode or Swift Playgrounds app project.
2. To enable saving images to your camera roll, add the **Photo Library Additions** (`NSPhotoLibraryAddUsageDescription`) capability in App Settings / `Info.plist`.
3. Run the app, open **API Key Settings** near the bottom of the screen, and paste your Pollinations Secret Key (`sk_...`).
