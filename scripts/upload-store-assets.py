#!/usr/bin/env python3
"""Upload the composed listing art to App Store Connect.

Puts the frames in `store/` onto the app's editable App Store version. It
never touches a version that is live or already in review, and it refuses to
submit anything for review — that stays a decision you make in Connect.

    scripts/upload-store-assets.py              # show what would be uploaded
    scripts/upload-store-assets.py --confirm    # actually upload

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH in the environment.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_api as asc  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "store"
BUNDLE_ID = "com.gabrielaboy.steady"

# Connect's enum names lag the hardware: the 6.9" iPhone slot is still called
# APP_IPHONE_67 and the 13" iPad slot APP_IPAD_PRO_3GEN_129.
#
# The screenshot slots take the device's own size. The preview slots do not,
# and they fail silently — the upload succeeds, then the asset turns FAILED
# minutes later with nothing but "ASSET_FAILED" to go on. So the size each
# preview slot actually wants is written down here and checked before sending.
@dataclass(frozen=True)
class Target:
    folder: str
    label: str
    screenshot_type: str
    preview_type: str
    preview_size: tuple[int, int]


TARGETS = [
    Target("iPhone-17-Pro-Max", "iPhone 6.9″", "APP_IPHONE_67", "IPHONE_67", (886, 1920)),
    Target("iPad-Pro-13-inch-M5", "iPad 13″", "APP_IPAD_PRO_3GEN_129", "IPAD_PRO_3GEN_129",
           (1200, 1600)),
]


# The 2026 media model added two landscape placements beside the screenshots.
# They do not live in a per-size set the way screenshots and previews do: the
# image goes into the app's asset library, and a placement record binds it to
# one localization. There is one asset per placement per localization, so a
# re-upload replaces rather than appends.
CREATIVES = {
    "header-5244x2950.png": ("PRODUCT_PAGE_HEADER_ASSET", "product page header"),
    "search-5244x2950.png": ("APP_STORE_SEARCH_RESULTS_ASSET", "search results asset"),
}

# Both placements accept this, which is why the compositor renders one shape.
CREATIVE_SIZE = (5244, 2950)


def video_size(path: Path) -> tuple[int, int]:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True).stdout.strip()
    width, height = out.split("x")[:2]
    return int(width), int(height)

# Only a version in one of these states can be edited.
EDITABLE = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


def find_version(tok: str) -> tuple[str, str]:
    apps = asc.request("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}", tok=tok)
    if not apps["data"]:
        raise SystemExit(f"no app with bundle id {BUNDLE_ID}")
    app = apps["data"][0]
    print(f"app      {app['attributes']['name']}  ({BUNDLE_ID}, id {app['id']})")

    versions = asc.request(
        "GET", f"/v1/apps/{app['id']}/appStoreVersions?limit=20", tok=tok)
    editable = [
        v for v in versions["data"]
        if v["attributes"]["platform"] == "IOS"
        and v["attributes"]["appStoreState"] in EDITABLE
    ]
    if not editable:
        states = ", ".join(
            f"{v['attributes']['versionString']} ({v['attributes']['appStoreState']})"
            for v in versions["data"]
        )
        raise SystemExit(f"no editable iOS version to upload into. Found: {states}")
    version = editable[0]
    print(f"version  {version['attributes']['versionString']}  "
          f"({version['attributes']['appStoreState']})")
    return version["id"], app["id"]


def localization(version_id: str, tok: str) -> tuple[str, str]:
    locs = asc.request(
        "GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50", tok=tok)
    if not locs["data"]:
        raise SystemExit("the version has no localizations")
    # en-US if it is there, otherwise whatever the app's primary locale is.
    chosen = next(
        (l for l in locs["data"] if l["attributes"]["locale"] == "en-US"), locs["data"][0])
    print(f"locale   {chosen['attributes']['locale']}")
    return chosen["id"], chosen["attributes"]["locale"]


def existing_set(parent_id: str, kind: str, type_key: str, type_value: str, tok: str):
    """The set for this display type, if the listing already has one."""
    path = {
        "appScreenshotSets": f"/v1/appStoreVersionLocalizations/{parent_id}/appScreenshotSets",
        "appPreviewSets": f"/v1/appStoreVersionLocalizations/{parent_id}/appPreviewSets",
    }[kind]
    for item in asc.request("GET", f"{path}?limit=50", tok=tok)["data"]:
        if item["attributes"][type_key] == type_value:
            return item
    return None


def ensure_set(loc_id: str, kind: str, type_key: str, type_value: str, tok: str) -> str:
    found = existing_set(loc_id, kind, type_key, type_value, tok)
    if found:
        return found["id"]
    created = asc.request("POST", f"/v1/{kind}", {
        "data": {
            "type": kind,
            "attributes": {type_key: type_value},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                }
            },
        }
    }, tok=tok)
    return created["data"]["id"]


def names_in_set(kind: str, set_kind: str, set_id: str, tok: str) -> set[str]:
    """File names already on the listing, so a re-run adds rather than duplicates."""
    items = asc.request("GET", f"/v1/{set_kind}/{set_id}/{kind}?limit=50", tok=tok)
    return {i["attributes"].get("fileName") for i in items["data"]}


def put_asset(kind: str, set_id: str, path: Path, tok: str) -> None:
    """Reserve, upload and commit one screenshot or preview."""
    blob = path.read_bytes()
    relationship = {
        "appScreenshots": ("appScreenshotSet", "appScreenshotSets"),
        "appPreviews": ("appPreviewSet", "appPreviewSets"),
    }[kind]

    reservation = asc.request("POST", f"/v1/{kind}", {
        "data": {
            "type": kind,
            "attributes": {"fileSize": len(blob), "fileName": path.name},
            "relationships": {
                relationship[0]: {"data": {"type": relationship[1], "id": set_id}}
            },
        }
    }, tok=tok)

    asset_id = reservation["data"]["id"]
    asc.upload(reservation["data"]["attributes"]["uploadOperations"], blob)
    asc.request("PATCH", f"/v1/{kind}/{asset_id}", {
        "data": {
            "type": kind,
            "id": asset_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": hashlib.md5(blob).hexdigest(),
            },
        }
    }, tok=tok)


def png_info(path: Path) -> tuple[tuple[int, int], bool]:
    """((width, height), has_alpha), read straight out of the IHDR chunk.

    Connect rejects a creative carrying an alpha channel, and a wrong size
    fails the same quiet way the preview sizes above do — so both are checked
    before anything is sent rather than discovered on the listing later.
    """
    header = path.read_bytes()[:26]
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} is not a PNG")
    width, height = struct.unpack(">II", header[16:24])
    return (width, height), header[25] in (4, 6)


def await_asset(image_id: str, path: Path, tok: str) -> str:
    """Block until Apple has processed the upload, or says it failed."""
    state = "UNKNOWN"
    for _ in range(30):
        attributes = asc.request(
            "GET", f"/v1/appAssetLibraryImages/{image_id}", tok=tok)["data"]["attributes"]
        state = attributes.get("state") or (
            attributes.get("assetDeliveryState") or {}).get("state") or "UNKNOWN"
        # PREPARE_FOR_SUBMISSION is what a finished asset-library image sits
        # at — it means "ready, waiting for the version to be submitted", not
        # "still processing". Every screenshot already on the listing reads
        # the same way.
        if state in {"COMPLETE", "PREPARED", "ACTIVE", "READY", "PREPARE_FOR_SUBMISSION"}:
            return state
        if state in {"FAILED", "REJECTED"}:
            raise SystemExit(
                f"{path.name} came back {state}: {attributes.get('stateDetails')}")
        time.sleep(4)
    raise SystemExit(f"{path.name} was still {state} after two minutes")


def placements(loc_id: str, tok: str) -> list[dict]:
    return asc.request(
        "GET", f"/v1/appStoreVersionLocalizations/{loc_id}/placements?limit=50",
        tok=tok)["data"]


def put_creative(app_id: str, loc_id: str, path: Path, placement_type: str, tok: str) -> None:
    """Reserve, upload and commit one creative, then place it on the listing."""
    blob = path.read_bytes()
    reservation = asc.request("POST", "/v1/appAssetLibraryImages", {
        "data": {
            "type": "appAssetLibraryImages",
            "attributes": {
                "fileName": path.name,
                "fileSize": len(blob),
                "category": "CREATIVE_ASSETS",
            },
            "relationships": {
                "assetLibrary": {"data": {"type": "appAssetLibraries", "id": app_id}}
            },
        }
    }, tok=tok)

    image_id = reservation["data"]["id"]
    asc.upload(reservation["data"]["attributes"]["uploadOperations"], blob)
    # An asset-library image commits on `uploaded` alone — unlike a screenshot
    # or a preview, it rejects sourceFileChecksum.
    asc.request("PATCH", f"/v1/appAssetLibraryImages/{image_id}", {
        "data": {
            "type": "appAssetLibraryImages",
            "id": image_id,
            "attributes": {"uploaded": True},
        }
    }, tok=tok)
    await_asset(image_id, path, tok)

    for placement in placements(loc_id, tok):
        if placement["attributes"].get("placementType") == placement_type:
            asc.request(
                "DELETE", f"/v1/appAssetLibraryPlacements/{placement['id']}", tok=tok)
            print("   replaced the one already on the listing")

    asc.request("POST", "/v1/appAssetLibraryPlacements", {
        "data": {
            "type": "appAssetLibraryPlacements",
            "attributes": {"placementType": placement_type},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                },
                "image": {"data": {"type": "appAssetLibraryImages", "id": image_id}},
            },
        }
    }, tok=tok)


def plan_creatives(loc_id: str, tok: str) -> list[tuple[Path, str, str]]:
    """The creatives on disk, size-checked, against what is already placed."""
    placed = {p["attributes"].get("placementType") for p in placements(loc_id, tok)}
    plan = []
    for name, (placement_type, label) in CREATIVES.items():
        path = STORE / "creative" / name
        if not path.exists():
            print(f"{label}: no {path.relative_to(ROOT)}, skipping")
            continue
        size, has_alpha = png_info(path)
        if size != CREATIVE_SIZE:
            raise SystemExit(
                f"{path.relative_to(ROOT)} is {size[0]}x{size[1]}, but the "
                f"{placement_type} slot takes {CREATIVE_SIZE[0]}x{CREATIVE_SIZE[1]}. "
                f"Rebuild it with scripts/build-store-assets.py")
        if has_alpha:
            raise SystemExit(
                f"{path.relative_to(ROOT)} has an alpha channel, which Connect "
                f"rejects. Rebuild it with scripts/build-store-assets.py")
        print(f"{label}  ({placement_type})")
        print(f"   {name}" + ("  [replaces the one on the listing]"
                              if placement_type in placed else ""))
        plan.append((path, placement_type, label))
    return plan


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--confirm", action="store_true",
                        help="actually upload; without it nothing is sent")
    args = parser.parse_args()

    tok = asc.token()
    version_id, app_id = find_version(tok)
    loc_id, _ = localization(version_id, tok)
    print()

    plan = []
    for target in TARGETS:
        folder = STORE / target.folder
        shots = sorted(folder.glob("[0-9][0-9]-*.png"))
        preview = folder / "app-preview.mp4"
        if not shots:
            print(f"{target.label}: no frames in {folder.relative_to(ROOT)}, skipping")
            continue
        if preview.exists():
            size = video_size(preview)
            if size != target.preview_size:
                raise SystemExit(
                    f"{preview.relative_to(ROOT)} is {size[0]}x{size[1]}, but the "
                    f"{target.preview_type} slot only takes "
                    f"{target.preview_size[0]}x{target.preview_size[1]}. Rebuild it:\n"
                    f"  scripts/build-app-preview.sh <raw.mov> {preview.relative_to(ROOT)} "
                    f"START LENGTH SPEED {target.preview_size[0]}x{target.preview_size[1]}")
        plan.append((target, shots, preview if preview.exists() else None))

        current = existing_set(loc_id, "appScreenshotSets", "screenshotDisplayType",
                               target.screenshot_type, tok)
        already = 0
        if current:
            already = len(asc.request(
                "GET", f"/v1/appScreenshotSets/{current['id']}/appScreenshots?limit=50",
                tok=tok)["data"])
        print(f"{target.label}  ({target.screenshot_type})")
        print(f"   {len(shots)} screenshots" + (f"  [{already} already on the listing]" if already else ""))
        if preview.exists():
            print(f"   1 app preview  ({preview.name})")

    creatives = plan_creatives(loc_id, tok)

    if not args.confirm:
        print("\nDry run — nothing was sent. Re-run with --confirm to upload.")
        return

    print()
    for target, shots, preview in plan:
        print(f"{target.label}")
        set_id = ensure_set(loc_id, "appScreenshotSets", "screenshotDisplayType",
                            target.screenshot_type, tok)
        present = names_in_set("appScreenshots", "appScreenshotSets", set_id, tok)
        for shot in shots:
            if shot.name in present:
                print(f"   kept     {shot.name} (already on the listing)")
                continue
            put_asset("appScreenshots", set_id, shot, tok)
            print(f"   uploaded {shot.name}")
        if preview:
            preview_set = ensure_set(loc_id, "appPreviewSets", "previewType",
                                     target.preview_type, tok)
            if preview.name in names_in_set("appPreviews", "appPreviewSets", preview_set, tok):
                print(f"   kept     {preview.name} (already on the listing)")
            else:
                put_asset("appPreviews", preview_set, preview, tok)
                print(f"   uploaded {preview.name}")

    for path, placement_type, label in creatives:
        print(label)
        put_creative(app_id, loc_id, path, placement_type, tok)
        print(f"   uploaded {path.name}")

    print("\nUploaded. The version stays in Prepare for Submission — nothing has")
    print("been submitted for review, and nothing is public until you submit it.")


if __name__ == "__main__":
    main()
