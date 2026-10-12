#!/usr/bin/env python3
"""Enforces the promises Steady makes about privacy.

Steady's whole trust story is that it can't phone home and doesn't need "Allow
Full Access". That's a claim in the README, in the onboarding copy, and in the
PRD (FR-6) — so it should fail the build if it ever stops being true, rather
than being rechecked by hand.

Run: python3 scripts/check-privacy-invariants.py
"""
from __future__ import annotations

import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Code that ends up inside the keyboard extension. The container app is held to
# the same bar: no prediction, name or phrase data may leave the device.
SCANNED_DIRS = ["Shared", "KeyboardExtension", "App", "PredictiveEngine/Sources"]

# Networking entry points. Matched as whole words so `URL(fileURLWithPath:)` and
# `Bundle.module.url(forResource:)` — both legitimate local file access — pass.
NETWORK_APIS = [
    "URLSession",
    "URLRequest",
    "NSURLConnection",
    "NWConnection",
    "NWBrowser",
    "NWListener",
    "CFSocket",
    "CFStream",
    "WKWebView",
    "CFHTTP",
]
NETWORK_IMPORTS = ["Network", "CFNetwork", "WebKit"]

APP_GROUP = "group.com.gabrielaboy.steady"

failures: list[str] = []


def check_no_networking() -> None:
    api_pattern = re.compile(r"\b(" + "|".join(NETWORK_APIS) + r")\b")
    import_pattern = re.compile(r"^\s*import\s+(" + "|".join(NETWORK_IMPORTS) + r")\s*$", re.MULTILINE)

    for directory in SCANNED_DIRS:
        for path in sorted((ROOT / directory).rglob("*.swift")):
            text = path.read_text()
            relative = path.relative_to(ROOT)
            for match in api_pattern.finditer(text):
                line = text[: match.start()].count("\n") + 1
                failures.append(f"{relative}:{line}: networking API `{match.group(1)}` is not allowed")
            for match in import_pattern.finditer(text):
                line = text[: match.start()].count("\n") + 1
                failures.append(f"{relative}:{line}: `import {match.group(1)}` is not allowed")


def check_full_access_not_requested() -> None:
    plist_path = ROOT / "KeyboardExtension" / "Info.plist"
    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)

    attributes = plist.get("NSExtension", {}).get("NSExtensionAttributes", {})
    if "RequestsOpenAccess" not in attributes:
        failures.append("KeyboardExtension/Info.plist: RequestsOpenAccess must be declared")
    elif attributes["RequestsOpenAccess"] is not False:
        failures.append(
            "KeyboardExtension/Info.plist: RequestsOpenAccess must be false — "
            "Steady must never ask for Allow Full Access"
        )

    point = plist.get("NSExtension", {}).get("NSExtensionPointIdentifier")
    if point != "com.apple.keyboard-service":
        failures.append(f"KeyboardExtension/Info.plist: unexpected extension point {point!r}")


def check_app_transport_security() -> None:
    for path in sorted(ROOT.rglob("Info.plist")):
        # Skip build output: Xcode's own test-runner app ships an ATS exception
        # we neither wrote nor can change.
        if {".build", "build", "DerivedData"} & set(path.parts):
            continue
        with path.open("rb") as handle:
            plist = plistlib.load(handle)
        ats = plist.get("NSAppTransportSecurity", {})
        if ats.get("NSAllowsArbitraryLoads"):
            failures.append(f"{path.relative_to(ROOT)}: NSAllowsArbitraryLoads must not be set")


def check_app_group_matches() -> None:
    """A mismatched app group silently stops settings reaching the keyboard."""
    entitlements = {
        "App/Steady.entitlements": None,
        "KeyboardExtension/SteadyKeyboard.entitlements": None,
    }
    for relative in entitlements:
        with (ROOT / relative).open("rb") as handle:
            groups = plistlib.load(handle).get("com.apple.security.application-groups", [])
        entitlements[relative] = groups
        if groups != [APP_GROUP]:
            failures.append(f"{relative}: app group must be exactly [{APP_GROUP}], found {groups}")

    values = list(entitlements.values())
    if values[0] != values[1]:
        failures.append("App and keyboard extension declare different app groups")


def check_no_third_party_dependencies() -> None:
    """Steady ships no third-party code, so there is nothing that could start
    talking to the network behind our back. Keep it that way."""
    # `.package(...)` is only ever an external dependency; a target's own
    # `dependencies: ["PredictiveEngine"]` is internal wiring and fine.
    manifest = (ROOT / "PredictiveEngine" / "Package.swift").read_text()
    for match in re.finditer(r"\.package\s*\(", manifest):
        line = manifest[: match.start()].count("\n") + 1
        failures.append(
            f"PredictiveEngine/Package.swift:{line}: third-party package dependencies are not allowed"
        )

    pbxproj = (ROOT / "Steady.xcodeproj" / "project.pbxproj").read_text()
    if "XCRemoteSwiftPackageReference" in pbxproj:
        failures.append("Steady.xcodeproj: remote Swift package references are not allowed")


def check_site_loads_nothing_third_party() -> None:
    """docs/ tells visitors it loads no fonts, scripts or images from anyone
    else — the typeface is self-hosted precisely so that stays true. Anything
    the browser fetches automatically must therefore be a relative path."""
    # Attributes the browser fetches without being asked. `href` is only one of
    # these on <link>; on <a> it is a link the visitor chooses to follow.
    asset_pattern = re.compile(r"<(link|script|img|iframe|video|audio|source|embed)\b[^>]*>", re.IGNORECASE)
    url_pattern = re.compile(r"\b(?:src|href)\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
    # <link rel="canonical"> names the page's own address on the live
    # domain. It is metadata for crawlers, never a resource the browser
    # goes and gets, so an absolute URL there fetches nothing.
    canonical_pattern = re.compile(r"\brel\s*=\s*[\"']?canonical\b", re.IGNORECASE)

    for path in sorted((ROOT / "docs").rglob("*.html")):
        text = path.read_text()
        relative = path.relative_to(ROOT)
        for tag in asset_pattern.finditer(text):
            if canonical_pattern.search(tag.group(0)):
                continue
            for url in url_pattern.finditer(tag.group(0)):
                value = url.group(1)
                if value.startswith(("http://", "https://", "//")):
                    line = text[: tag.start()].count("\n") + 1
                    failures.append(
                        f"{relative}:{line}: <{tag.group(1).lower()}> loads {value} from another origin; "
                        "the site promises to fetch nothing third-party"
                    )

    for path in sorted((ROOT / "docs").rglob("*.css")):
        text = path.read_text()
        relative = path.relative_to(ROOT)
        for match in re.finditer(r"(?:url\(\s*[\"']?|@import\s+[\"'])(https?:)?//", text):
            line = text[: match.start()].count("\n") + 1
            failures.append(f"{relative}:{line}: stylesheet fetches a remote resource")


def main() -> int:
    check_no_networking()
    check_full_access_not_requested()
    check_app_transport_security()
    check_app_group_matches()
    check_no_third_party_dependencies()
    check_site_loads_nothing_third_party()

    if failures:
        print("Privacy invariants violated:\n")
        for failure in failures:
            print(f"  {failure}")
        print(f"\n{len(failures)} problem(s).")
        return 1

    print("Privacy invariants hold:")
    print("  - no networking APIs in any shipped code")
    print("  - RequestsOpenAccess is false (Full Access never requested)")
    print("  - no arbitrary-loads ATS exceptions")
    print(f"  - app and extension share exactly {APP_GROUP}")
    print("  - no third-party dependencies")
    print("  - docs/ fetches nothing from a third-party origin")
    return 0


if __name__ == "__main__":
    sys.exit(main())
