"""A small App Store Connect API client — just enough to publish listing art.

Credentials come from the environment, the same three values App Store Connect
hands out with an API key:

    ASC_KEY_ID      the key's ID
    ASC_ISSUER_ID   the issuer UUID for the team
    ASC_KEY_PATH    path to the AuthKey_<id>.p8 file
"""

from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric import utils as asym_utils

API = "https://api.appstoreconnect.apple.com"


class ASCError(RuntimeError):
    pass


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    """A fresh ES256 bearer token."""
    try:
        key_id = os.environ["ASC_KEY_ID"]
        issuer = os.environ["ASC_ISSUER_ID"]
        key_path = os.path.expanduser(os.environ["ASC_KEY_PATH"])
    except KeyError as missing:
        raise ASCError(f"{missing.args[0]} is not set") from None

    key = serialization.load_pem_private_key(open(key_path, "rb").read(), password=None)
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    # iat is backdated a minute: if this machine's clock runs even slightly
    # ahead of Apple's, a token issued "in the future" comes straight back as
    # 401 NOT_AUTHORIZED, which reads exactly like a bad key.
    payload = {"iss": issuer, "iat": now - 60, "exp": now + 900, "aud": "appstoreconnect-v1"}

    signing_input = f"{_b64(json.dumps(header).encode())}.{_b64(json.dumps(payload).encode())}"
    der = key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = asym_utils.decode_dss_signature(der)
    return f"{signing_input}.{_b64(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


def request(method: str, path: str, body=None, tok: str | None = None):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {tok or token()}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raise ASCError(f"{method} {url} -> {error.code}\n{error.read().decode()}") from None


def upload(operations: list[dict], blob: bytes) -> None:
    """Run the chunked PUTs App Store Connect hands back with a reservation."""
    for operation in operations:
        offset, length = operation["offset"], operation["length"]
        req = urllib.request.Request(
            operation["url"], data=blob[offset : offset + length], method=operation["method"]
        )
        for header in operation.get("requestHeaders", []):
            req.add_header(header["name"], header["value"])
        try:
            urllib.request.urlopen(req).read()
        except urllib.error.HTTPError as error:
            raise ASCError(f"chunk at {offset} failed: {error.code}\n{error.read().decode()}") from None
