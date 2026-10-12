# Steady

An iOS keyboard that reshapes itself as you type.

**Now in open beta.** [Join on TestFlight](https://testflight.apple.com/join/VVBRJSdn) ·
[steady site](https://steadykeyboard.com/) ·
[support](https://steadykeyboard.com/support.html) ·
[privacy](https://steadykeyboard.com/privacy.html)

Steady is built for people who type on a touchscreen but miss keys — tremor, limited
dexterity, single-finger or switch use. An on-device language model knows that after each
letter only a limited set of words remains possible, so Steady **enlarges the letters most
likely to come next and shrinks or removes the ones that can't follow**. Tap targets grow
as the word narrows.

Everything runs on the device. No network calls, and no "Allow Full Access" permission.

## What's here

| Path | What it is |
|---|---|
| `PredictiveEngine/` | The prediction engine as a standalone Swift package — a compiled, memory-mapped dictionary (`en.sdict`: a frequency-weighted byte trie plus a bigram next-word table) and the key-resize layout maths. No UIKit, no SwiftUI, fully unit tested. |
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
engine.nextLetterWeights(forPrefix: "th")          // weight per letter that can follow
engine.keyScales(forPrefix: "th", config: .motorAccessibility)
```

The dictionary is never parsed into memory. `scripts/build-dictionary.sh` compiles a
~47k-word frequency list and ~80k bigrams into `PredictiveEngine/Sources/PredictiveEngine/Resources/en.sdict`
(about 2.7 MB, committed). At runtime the file is memory-mapped and each keystroke reads only
the trie nodes it walks, so the keyboard extension's footprint stays flat however large the
word list grows. Sources and licenses are listed in `Resources/LICENSES.md` next to the file.

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

## The site

`docs/` is the GitHub Pages site: the landing page, the support page App Store Connect
points at, and the privacy policy. The landing page carries a live keyboard
(`docs/keyboard-demo.js`) that ports `KeyLayout.keyScales`, the tier colours and the three
strength profiles to JavaScript, over the top 6,000 words of the same frequency list the
dictionary is compiled from. **Change the resize maths in `PredictiveEngine` and that demo
needs the same change**, or the site stops telling the truth about the app. Everything the
site needs — typeface included — is served from `docs/`; it makes no third-party requests.

## Status

**Open beta**, distributed through TestFlight with a public link. The prediction engine, the
dynamic keyboard, suggestion chips, settings, practice pad, names, and phrases are built and
tested. English only. Not yet submitted to the App Store for public release.
