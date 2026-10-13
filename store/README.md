# App Store listing art

Everything in here is generated from the shipping build. Nothing is mocked up:
the screens are captured from `Steady.app` running on a simulator, so when the
keyboard changes, the listing can be regenerated instead of redrawn.

```sh
scripts/capture-store-assets.sh      # drive the app, capture raw screens + a screen recording
scripts/build-store-assets.py        # compose the captioned frames, the two creatives and the search mock
scripts/build-app-preview.sh store/raw/iPhone-17-Pro-Max/preview.mov \
    store/iPhone-17-Pro-Max/app-preview.mp4 21.5 58 2.2 886x1920
scripts/build-app-preview.sh store/raw/iPad-Pro-13-inch-M5/preview.mov \
    store/iPad-Pro-13-inch-M5/app-preview.mp4 43 58 2.2 1200x1600
scripts/upload-store-assets.py                 # dry run
scripts/upload-store-assets.py --confirm       # upload to App Store Connect
```

The preview step is the only one with numbers to tune — start, length, speed,
size. It trims the app launch off the front of the recording and plays the take
at 2.2x, because XCUITest spends about two seconds per key tap and the result at
1x is unwatchably slow. It refuses to write anything outside the 15–30s Connect
accepts. (The start offset shifts whenever the simulator's launch time does, so
check where the Practice pad appears before trusting the old numbers.)

The uploader only ever writes to an **editable** version — it refuses to touch
one that is live or in review — and it never submits anything for review. It
skips files already on the listing, so re-running it adds rather than
duplicates.

## App previews are not the screenshot size

This costs an hour if you learn it the hard way. A screenshot slot takes the
device's own resolution; the preview slot next to it does not, and Connect
**accepts the upload either way**. The asset reports `COMPLETE`, then turns
`FAILED` a few minutes later with no detail beyond `ASSET_FAILED`.

| Slot | Screenshots | App preview |
|---|---|---|
| `APP_IPHONE_67` / `IPHONE_67` | 1320 × 2868 | **886 × 1920** |
| `APP_IPAD_PRO_3GEN_129` / `IPAD_PRO_3GEN_129` | 2064 × 2752 | **1200 × 1600** |

`scripts/upload-store-assets.py` checks preview dimensions against that table
before sending anything, so the mistake can't be made twice.

The captions live in `SHOTS` at the top of `scripts/build-store-assets.py`;
the capture order lives in `UITests/StoreCaptureTests.swift`. Change a caption
in one place, re-run the compositor, done.

## What goes where in App Store Connect

| Connect field | File | Size |
|---|---|---|
| iPhone 6.9″ screenshots | `iPhone-17-Pro-Max/01…06.png` | 1320 × 2868 |
| iPhone 6.9″ app preview | `iPhone-17-Pro-Max/app-preview.mp4` | 1320 × 2868, 15–30s |
| iPad 13″ screenshots | `iPad-Pro-13-inch-M5/01, 02, 05, 06.png` | 2064 × 2752 |
| iPad 13″ app preview | `iPad-Pro-13-inch-M5/app-preview.mp4` | 2064 × 2752, 15–30s |
| App icon | `App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | 1024 × 1024, no alpha |
| Product page header | `creative/header-5244x2950.png` | 5244 × 2950 |
| Search results asset | `creative/search-5244x2950.png` | 5244 × 2950 |

Connect's enum names lag the hardware: the 6.9″ iPhone slot is still called
`APP_IPHONE_67` and the 13″ iPad slot `APP_IPAD_PRO_3GEN_129`. Both take the
current, larger screenshot sizes.

Those two display sizes are the only screenshot sets Connect requires for an
app that ships on both iPhone and iPad; every smaller size is scaled from them
automatically.

## The two creatives

The 2026 media model added two landscape placements beside the screenshots: a
**product page header** and a **search results asset**. Both accept 5244 × 2950,
so one aspect ratio serves both, and both are one layout at two scales — copy
left, device cluster right:

| | Devices | Type | Shows |
|---|---|---|---|
| Header | three, centre one stepped forward | smaller | texting the phrases and the variables: a word mid-tap, `Hi Mom, I'm running {minutes} late for {place}` with its chips, and names going into a half-written message |
| Search | one | much bigger | plain texting — it is read at thumbnail size, so fewer words and one screen |

The header leaves its lower-left corner empty on purpose: the App Store overlays
the app icon and name there.

The layout, the warm kicker over teal and every measurement are Emberly's
(`StravaApp/app-store/panels/render-creative.mjs` in the Emberly repo), so the
two listings in this account read as one house style. What stays Steady's is the
backdrop and the typeface, both shared with steadykeyboard.com — and because
Atkinson Hyperlegible sets wider than the SF Pro those measurements were made
in, the three-device headline runs at 4.9vw rather than 5.3vw.

Headlines, sub-copy and which captures appear are the `CREATIVES` map in
`scripts/build-store-assets.py`. Keep the lines short: the trio's copy column is
about 35vw wide, which is roughly thirteen characters a line at that size.

The search results asset is optional — without one the App Store falls back to
the screenshots and preview — and neither creative is wired into
`scripts/upload-store-assets.py` yet, so both go up by hand for now.

## Not App Store Connect fields

| File | What it's for |
|---|---|
| `header-2560x1340.png` | The header creative again at banner shape, for the places outside Connect that want one: a press kit, a featuring nomination, the top of a page. Same layout, 1.91:1 instead of 16:9. |
| `social-1200x630.png` | The same banner at Open Graph size, for `og:image` on steadykeyboard.com. Copied to `docs/social-card.png` by the same step, which is the file the site actually serves. |
| `search-result-preview.png` | A check, not a deliverable: the first three frames at the size App Store search actually shows them. If a caption can't be read here, shorten it. |

## Where the screenshots come from

Five of the six frames are Steady running as a real system keyboard **inside
Messages** — a real conversation, real sent messages, the extension doing the
work. That is the product; the container app's practice pad is only a place to
learn it. `StoreMessagesCaptureTests` drives those, and `StoreCaptureTests`
contributes the one remaining app screen, the settings.

Two things the simulator will not do, both cosmetic:

- **The recipient is a phone number.** The simulator's Messages has no compose
  button and does not resolve contacts for its seeded threads, so the thread
  cannot be addressed to a name. Capturing on a physical device with real
  contacts would fix it.
- **iPad stops at four frames.** XCUITest reports the keyboard surface's panel
  toolbar as half a point above the screen there and then refuses to tap it,
  so the Names and Phrases frames are iPhone-only. The capture detects this and
  carries on rather than failing — see `panelsAreReachable`.

## The order matters

Search results show the **first three** frames only, at about 150pt wide. One
through three are the ones that have to carry the whole idea on their own —
the keys growing, the one-tap completion, and the row collapsing to a single
key. The rest are for people who already tapped through.
