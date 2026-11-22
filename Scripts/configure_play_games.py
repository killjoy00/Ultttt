#!/usr/bin/env python3
"""Provision or audit UTTT Play Games achievements/leaderboard using Google's API.

Uses the same Google Play service-account OAuth scope as EZTrivia's
read-only Play Games audit. Never publishes Play Games configuration or
an Android build. Resource creation is idempotent by localized display name.

Usage:
  GOOGLE_PLAY_ACCESS_TOKEN=... python3 Scripts/configure_play_games.py --game-id 123456789012
  GOOGLE_PLAY_ACCESS_TOKEN=... python3 Scripts/configure_play_games.py --game-id 123456789012 --apply

The generated android/play-games.properties contains only PUBLIC Google
resource IDs, never Google credentials. It is intended to be committed
after a successful audit, not automatically pushed from CI.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

API = "https://www.googleapis.com/games/v1configuration"
ROOT = Path(__file__).resolve().parents[1]
PROPERTIES = ROOT / "android/play-games.properties"

ACHIEVEMENTS = (
    ("First Win", "Win your first game against the computer.", 10, "PGS_FIRST_WIN_ID"),
    ("Five Wins", "Win five games against the computer.", 20, "PGS_FIVE_WINS_ID"),
    ("Ten Wins", "Win ten games against the computer.", 30, "PGS_TEN_WINS_ID"),
    ("First Online Win", "Win your first online match.", 20, "PGS_FIRST_ONLINE_WIN_ID"),
    ("25 Online Wins", "Win twenty-five online matches.", 40, "PGS_TWENTY_FIVE_ONLINE_WINS_ID"),
)
LEADERBOARD_NAME = "Online Wins"
LEADERBOARD_KEY = "PGS_ONLINE_WINS_LEADERBOARD_ID"


def api_json(url: str, token: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    raw = None if body is None else json.dumps(body, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=raw,
        method="POST" if raw is not None else "GET",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "UltimateTTT-PlayGames-Provision/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        error = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Play Games API returned HTTP {exc.code}: {error[:3000]}") from exc


def list_all(game_id: str, resource_type: str, token: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    page = ""
    while True:
        params = {"maxResults": "200"}
        if page:
            params["pageToken"] = page
        url = f"{API}/applications/{game_id}/{resource_type}?" + urllib.parse.urlencode(params)
        data = api_json(url, token)
        result.extend(data.get("items") or [])
        page = str(data.get("nextPageToken") or "")
        if not page:
            return result


def localized_name(resource: dict[str, Any]) -> str:
    """Match either draft or published English name; casefold for safe reruns."""
    for layer in ("draft", "published"):
        for entry in ((resource.get(layer) or {}).get("name") or {}).get("translations", []):
            if entry.get("locale", "").lower().startswith("en"):
                return str(entry.get("value", "")).strip().casefold()
    return ""


def by_name(items: list[dict[str, Any]], desired_name: str) -> dict[str, Any] | None:
    found = [item for item in items if localized_name(item) == desired_name.casefold()]
    if len(found) > 1:
        raise RuntimeError(f"Multiple Play Games resources match {desired_name!r}; refusing to guess")
    return found[0] if found else None


def en(text: str) -> dict[str, Any]:
    return {"translations": [{"locale": "en-US", "value": text}]}


def achievement_body(name: str, desc: str, points: int) -> dict[str, Any]:
    return {
        "achievementType": "STANDARD",
        "initialState": "REVEALED",
        "draft": {
            "name": en(name),
            "description": en(desc),
            "pointValue": points,
        },
    }


def leaderboard_body() -> dict[str, Any]:
    return {
        "scoreOrder": "LARGER_IS_BETTER",
        "scoreMin": "0",
        "scoreMax": "1000000",
        "draft": {
            "name": en(LEADERBOARD_NAME),
            "scoreFormat": {"numberFormatType": "NUMERIC", "numDecimalPlaces": 0},
        },
    }


def inspect_resources(game_id: str, token: str, apply: bool) -> dict[str, str]:
    achievements = list_all(game_id, "achievements", token)
    leaderboards = list_all(game_id, "leaderboards", token)
    print(f"Found {len(achievements)} existing achievements and {len(leaderboards)} existing leaderboards.")
    out: dict[str, str] = {"PLAY_GAMES_APP_ID": game_id}

    for name, description, points, key in ACHIEVEMENTS:
        item = by_name(achievements, name)
        if item is not None and item.get("achievementType") != "STANDARD":
            raise RuntimeError(f"Existing {name!r} is not STANDARD; refusing to change its type")
        if item is None:
            if not apply:
                print(f"PLAN create achievement: {name}")
                continue
            item = api_json(
                f"{API}/applications/{game_id}/achievements",
                token,
                achievement_body(name, description, points),
            )
            print(f"Created achievement: {name}")
        else:
            print(f"Using existing achievement: {name}")
        identifier = item.get("id")
        if not identifier or not re.fullmatch(r"[A-Za-z0-9_-]+", str(identifier)):
            raise RuntimeError(f"Invalid achievement ID returned for {name}")
        out[key] = str(identifier)

    item = by_name(leaderboards, LEADERBOARD_NAME)
    if item is not None and item.get("scoreOrder") != "LARGER_IS_BETTER":
        raise RuntimeError("Existing Online Wins leaderboard has wrong score order")
    if item is None:
        if not apply:
            print("PLAN create leaderboard: Online Wins")
        else:
            item = api_json(
                f"{API}/applications/{game_id}/leaderboards",
                token,
                leaderboard_body(),
            )
            print("Created leaderboard: Online Wins")
    else:
        print("Using existing leaderboard: Online Wins")
    if item is not None:
        identifier = item.get("id")
        if not identifier or not re.fullmatch(r"[A-Za-z0-9_-]+", str(identifier)):
            raise RuntimeError("Invalid Online Wins leaderboard ID returned")
        out[LEADERBOARD_KEY] = str(identifier)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-id", required=True, help="Numeric Play Games project ID (not package name)")
    parser.add_argument("--apply", action="store_true", help="Create missing drafts; never publish")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]{8,20}", args.game_id):
        parser.error("--game-id must be the numeric Play Games Services project ID")
    token = os.environ.get("GOOGLE_PLAY_ACCESS_TOKEN", "").strip()
    if not token:
        raise RuntimeError("GOOGLE_PLAY_ACCESS_TOKEN not set; use the existing Google Play service account")
    ids = inspect_resources(args.game_id, token, args.apply)
    required = ["PLAY_GAMES_APP_ID"] + [key for _, _, _, key in ACHIEVEMENTS] + [LEADERBOARD_KEY]
    print("Resources:\n" + "\n".join(f"  {key}={ids.get(key, '<pending>')}" for key in required))
    if len(ids) == len(required):
        PROPERTIES.write_text(
            "# Generated from Play Games Services Publishing API; public IDs only.\n"
            + "\n".join(f"{key}={ids[key]}" for key in required)
            + "\n",
            encoding="utf-8",
        )
        print(f"Saved public Android configuration: {PROPERTIES}")
    else:
        print("Configuration incomplete; no properties file was changed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
