# Headroom

A macOS menu bar app that monitors your Claude.ai usage limits in real-time.

No human wrote a single line of code in this project. Every line of Swift, every build configuration, every Makefile target -- all written by Claude (Opus). The human's contribution was choosing the app icon (via Midjourney) and saying things like "it doesn't work" and "can we make it not boring". The AI did the rest.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Built by](https://img.shields.io/badge/built%20by-Claude-blueviolet)

## What it does

Headroom sits in your menu bar and shows your current Claude.ai usage at a glance:

```
🧠 SL 10% WL 6%
```

Click it for the full breakdown:

- **Session Limit (5h)** -- utilization with progress bar and reset countdown
- **Weekly Limit (7d)** -- utilization with progress bar and reset countdown
- **Model-specific limits** -- Opus, Sonnet, OAuth apps, Cowork (when active)
- **Extra Usage** -- dollar spend tracking with utilization bar
- **Predictions** -- estimated time until you hit a limit, based on your usage rate

## Features

- **Configurable menu bar display** -- use placeholders like `{sl}`, `{wl}`, `{sl_eta}` to build your own format string
- **Usage prediction** -- linear regression on a rolling window of samples estimates when you'll hit limits
- **Persistent history** -- usage samples stored as a time series, survives restarts
- **Secure auth** -- session stored in macOS Keychain, Google OAuth supported via native WebView
- **Launch at login** -- optional, via macOS `SMAppService`
- **Configurable poll interval** -- 30s, 60s, 2m, or 5m

## Available placeholders

| Placeholder | Description |
|---|---|
| `{sl}` | Session limit (5h) utilization % |
| `{wl}` | Weekly limit (7d) utilization % |
| `{sl_reset}` | Session limit reset countdown |
| `{wl_reset}` | Weekly limit reset countdown |
| `{sl_eta}` | Predicted time to hit session limit |
| `{wl_eta}` | Predicted time to hit weekly limit |
| `{sonnet}` | Sonnet (7d) utilization % |
| `{opus}` | Opus (7d) utilization % |
| `{extra}` | Extra usage utilization % |
| `{extra_used}` | Extra usage $ spent |
| `{extra_limit}` | Extra usage $ limit |

## Building

### Prerequisites

- macOS 14.0+
- Xcode 15+ (with command line tools)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Build

```sh
git clone https://github.com/matjam/headroom.git
cd headroom
cp .env.example .env
# Edit .env with your Apple Development Team ID (optional, for code signing)
make
```

### Run

```sh
make run
```

### Create DMG

```sh
make dmg
```

This builds a release configuration and packages `Headroom.app` into `dist/Headroom.dmg` with a symlink to `/Applications`.

### All targets

| Target | Description |
|---|---|
| `make` | Debug build (default) |
| `make build` | Debug build |
| `make release` | Release build |
| `make dmg` | Release build + create DMG |
| `make run` | Build and launch |
| `make clean` | Remove build artifacts |

## How it works

1. Click the menu bar item, click **Sign In**
2. A window opens with the Claude.ai login page
3. Sign in with Google (or however you authenticate)
4. The window closes, usage data appears in the menu bar and popover
5. Data refreshes automatically at your configured interval

### Authentication

Headroom authenticates by capturing the `sessionKey` cookie from the Claude.ai login flow via a native `WKWebView`. This is the same session cookie your browser uses. The session key is stored in the macOS Keychain.

### Predictions

Usage samples are recorded at each poll interval into a circular buffer (up to 1000 samples, ~16 hours at 60s intervals). Linear regression on the most recent samples estimates the rate of usage increase and predicts when you'll hit 100%.

Predictions become more accurate as samples accumulate. The history is persisted to `~/Library/Application Support/Headroom/usage_history.json` and survives restarts.

## License

MIT

## The human-AI collaboration

This project was built in a single session, from zero to distributable `.dmg`, in roughly 2 hours. A native macOS app with OAuth login, Keychain integration, real-time API polling, usage prediction via linear regression, persistent time-series storage, configurable UI, and a proper build system. By hand, this would comfortably be a week of work for an experienced Swift developer.

The AI wrote every line of code, but the human was far from idle. The human contributed:

- **Product vision** -- knowing what problem to solve and what the UX should feel like
- **Domain knowledge** -- providing the actual API endpoint and response format by inspecting the Claude.ai web app, which no AI could have done from the outside
- **Architectural direction** -- "just open a normal window" saved an hour of fighting SwiftUI's `MenuBarExtra` scene limitations
- **Real-time QA** -- testing each build, reporting exactly what failed ("the Google auth button stalls on redirect"), which let the AI diagnose and fix issues it couldn't observe
- **Taste** -- choosing the name, the icon, what information matters, and when something felt wrong

The AI contributed speed, breadth of knowledge (Swift, SwiftUI, AppKit, WKWebView, OAuth flows, Keychain, `hdiutil`, xcodegen, Makefile, linear regression), and the ability to hold the entire codebase in context while making changes across multiple files simultaneously.

Neither could have built this alone in 2 hours. The human without the AI would have spent days on boilerplate. The AI without the human would have built something that compiled but didn't actually work, because it couldn't click the buttons.

## Credits

- **Code**: Claude (Anthropic) -- every single line
- **Architecture decisions**: Claude, with occasional human steering
- **App icon**: Human + Midjourney
- **QA**: Human clicking buttons and reporting what broke
- **Product direction**: Human ("I want to see my usage in the menu bar")
- **Naming**: Human chose "Headroom" from a list of AI-generated options
