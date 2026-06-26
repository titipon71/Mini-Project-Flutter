"""
Simple API test script for Twebtoon backend.
Usage:
    python test_api.py                        # test public endpoints only
    python test_api.py --token <JWT>          # also test auth-protected endpoints
    python test_api.py --url http://host:port # custom base URL (default: http://localhost:8000)
"""
import sys
import json
import argparse
import requests

# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #
parser = argparse.ArgumentParser()
parser.add_argument("--url", default="http://localhost:8000")
parser.add_argument("--token", default=None, help="JWT access_token (from /auth/token)")
args = parser.parse_args()

BASE = args.url.rstrip("/")
TOKEN = args.token

# --------------------------------------------------------------------------- #
# Tiny test runner
# --------------------------------------------------------------------------- #
passed = 0
failed = 0
skipped = 0

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
RESET  = "\033[0m"


def ok(name: str, detail: str = ""):
    global passed
    passed += 1
    print(f"  {GREEN}PASS{RESET}  {name}" + (f"  ({detail})" if detail else ""))


def fail(name: str, reason: str):
    global failed
    failed += 1
    print(f"  {RED}FAIL{RESET}  {name}  -> {reason}")


def skip(name: str, reason: str = "no token"):
    global skipped
    skipped += 1
    print(f"  {YELLOW}SKIP{RESET}  {name}  ({reason})")


def check(name: str, resp: requests.Response, expect_status: int, *, key: str | None = None):
    """Assert status code and optionally that a key exists in the JSON body."""
    if resp.status_code != expect_status:
        fail(name, f"expected {expect_status}, got {resp.status_code} — {resp.text[:120]}")
        return None
    try:
        body = resp.json()
    except Exception:
        fail(name, "response is not JSON")
        return None
    if key and key not in body:
        fail(name, f"missing key '{key}' in response")
        return None
    ok(name, f"status {resp.status_code}")
    return body


def auth_headers() -> dict:
    return {"Authorization": f"Bearer {TOKEN}"}


# --------------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------------- #
def test_public():
    print("\n[Public endpoints]")

    # Health check
    r = requests.get(f"{BASE}/health", timeout=5)
    check("GET /health", r, 200, key="ok")

    # List mangas (public read)
    r = requests.get(f"{BASE}/api/v1/mangas", timeout=5)
    body = check("GET /api/v1/mangas", r, 200, key="items")

    manga_id = None
    if body and body["items"]:
        manga_id = body["items"][0]["id"]
        r2 = requests.get(f"{BASE}/api/v1/mangas/{manga_id}", timeout=5)
        check(f"GET /api/v1/mangas/{manga_id}", r2, 200, key="id")

    # Non-existent manga should be 404
    r = requests.get(f"{BASE}/api/v1/mangas/999999", timeout=5)
    check("GET /api/v1/mangas/999999 (404 expected)", r, 404)

    # Accessing protected route without token should be 401
    r = requests.get(f"{BASE}/api/v1/me", timeout=5)
    check("GET /api/v1/me without token (401 expected)", r, 401)

    return manga_id


def test_auth(manga_id: int | None):
    print("\n[Auth-protected endpoints]")

    if not TOKEN:
        for name in [
            "GET /api/v1/me",
            "GET /api/v1/me/roles",
            "PATCH /api/v1/me/profile",
            "POST /api/v1/mangas (admin)",
        ]:
            skip(name)
        return

    # Current user profile
    r = requests.get(f"{BASE}/api/v1/me", headers=auth_headers(), timeout=5)
    body = check("GET /api/v1/me", r, 200, key="uid")

    # Current user roles
    r = requests.get(f"{BASE}/api/v1/me/roles", headers=auth_headers(), timeout=5)
    check("GET /api/v1/me/roles", r, 200, key="admin")

    # Update display name
    r = requests.patch(
        f"{BASE}/api/v1/me/profile",
        headers=auth_headers(),
        json={"displayName": "Test Runner"},
        timeout=5,
    )
    check("PATCH /api/v1/me/profile", r, 200, key="ok")

    # Admin-only: create manga (expect 403 if user is not admin, 201 if admin)
    r = requests.post(
        f"{BASE}/api/v1/mangas",
        headers=auth_headers(),
        json={"name": "__test_manga__", "coverUrl": None, "backgroundUrl": None},
        timeout=5,
    )
    if r.status_code == 201:
        new_id = r.json().get("id")
        ok("POST /api/v1/mangas (admin)", f"created id={new_id}")

        # Clean up
        r2 = requests.delete(f"{BASE}/api/v1/mangas/{new_id}", headers=auth_headers(), timeout=5)
        check(f"DELETE /api/v1/mangas/{new_id} (cleanup)", r2, 200)
    elif r.status_code == 403:
        ok("POST /api/v1/mangas (admin)", "403 Forbidden — current user is not admin (expected)")
    else:
        fail("POST /api/v1/mangas (admin)", f"unexpected status {r.status_code}")


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main():
    print(f"Target: {BASE}")
    print(f"Token:  {'(provided)' if TOKEN else '(none — auth tests will be skipped)'}")

    try:
        manga_id = test_public()
        test_auth(manga_id)
    except requests.exceptions.ConnectionError:
        print(f"\n{RED}ERROR{RESET} Cannot connect to {BASE}. Is the server running?")
        sys.exit(1)

    total = passed + failed + skipped
    print(f"\n{'='*40}")
    print(f"Results: {total} tests | {GREEN}{passed} passed{RESET} | {RED}{failed} failed{RESET} | {YELLOW}{skipped} skipped{RESET}")
    print(f"{'='*40}")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
