# Steady

An iOS keyboard that reshapes itself as you type.

Steady is built for people who type on a touchscreen but miss keys — tremor, limited
dexterity, single-finger or switch use. An on-device language model knows that after each
letter only a limited set of words remains possible, so Steady **enlarges the letters most
likely to come next and shrinks or removes the ones that can't follow**. Tap targets grow
as the word narrows.

Everything runs on the device. No network calls, and no "Allow Full Access" permission.

## What's here

| Path | What it is |
|---|---|
| `PredictiveEngine/` | The prediction engine as a standalone Swift package — a frequency-weighted prefix trie, a bigram next-word model, and the key-resize layout maths. No UIKit, no SwiftUI, fully unit tested. |
| `Shared/` | The keyboard UI and shared state, compiled into **both** targets. Writes through a `TextSink` protocol so the same code backs the real keyboard and the in-app practice pad. |
| `KeyboardExtension/` | The system-wide keyboard extension. Hosts the shared surface and types through `UITextDocumentProxy`. |
| `App/` | The container app: enable-the-keyboard onboarding, settings, practice pad, and the editors for saved names and phrases. |
| `UITests/` | XCUITests driving the real app on a simulator. |

## How it works

`PredictiveEngine` turns the text before the cursor into a weight per possible next letter,
then into a display scale per key:

```swift
let engine = try PredictiveEngine.loadBundled()
engine.completions(forPrefix: "th", limit: 3)      // the, that, this
engine.nextLetterWeights(forPrefix: "th")          // only a e i o r u w y are possible
engine.keyScales(forPrefix: "th", config: .motorAccessibility)
```

A scale of `0` means the key is impossible and gets removed from the row. Scales above
`1.0` grow the key in place — rows keep a fixed height and keys never reorder, so a key
you're reaching for doesn't move out from under you.

Three resize profiles are exposed in settings: **Off**, **Medium** (unlikely letters shrink
and fade), and **Aggressive** (impossible letters are removed outright).

## Beyond typing

- **Names** — saved entries that insert verbatim, for proper nouns prediction will never guess.
- **Phrases** — sentence templates with `{slot}` variables. A `{name}` slot draws from your
  Names list. Picking a phrase walks you through each blank with large chips, then inserts
  the finished sentence.

Both are edited in the app and shared to the keyboard through an app group.

## Building

Requires Xcode 16 or newer; the deployment target is iOS 16.

```sh
open Steady.xcodeproj           # or:
xcodebuild -scheme Steady -destination 'generic/platform=iOS Simulator' build
xcodebuild test -scheme Steady -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
cd PredictiveEngine && swift test
```

To use the keyboard itself: run the app, then Settings › General › Keyboard › Keyboards ›
Add New Keyboard › Steady. Hold the globe key in any app to switch to it.

## Tests

| Suite | Covers |
|---|---|
| `PredictiveEngineTests` | Completion ranking, next-letter weights, bigram prediction, the resize profiles, and bundled-lexicon loading. |
| `SteadyUITests` | The keyboard's behaviour driven through the app's practice pad — resizing, chip insertion, quick-insert, and the phrase fill flow. Runs anywhere. |
| `ExtensionInHostAppTest` | The keyboard running for real as a system keyboard in Safari. Needs a one-time simulator setup; skips itself with a pointer if that hasn't been done. |

```sh
scripts/enable-keyboard-in-simulator.sh    # enables Steady on the booted simulator
```

That script does what a user does in Settings — enables the keyboard — and also turns off
the simulator's hardware keyboard and suppresses the system keyboard's one-time tutorial,
neither of which can be scripted any other way.

> The bundle identifier prefix (`com.gabrielaboy.steady`) and the app group are placeholders.
> Point them at a domain you control before distributing.

## Status

MVP in development. The prediction engine, the dynamic keyboard, suggestion chips, settings,
practice pad, names, and phrases are built and tested. Not yet submitted to the App Store.
