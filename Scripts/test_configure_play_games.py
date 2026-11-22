#!/usr/bin/env python3
"""No-network tests for UTTT Google Play Games draft provisioning."""
import unittest
from unittest.mock import patch
import configure_play_games as pgs


def resource(name, id_, kind=None, score_order=None):
    item = {
        "id": id_,
        "draft": {"name": {"translations": [{"locale": "en-US", "value": name}]}},
    }
    if kind is not None:
        item["achievementType"] = kind
    if score_order is not None:
        item["scoreOrder"] = score_order
    return item


class PlayGamesConfigTest(unittest.TestCase):
    def test_create_missing_resources(self):
        new_ids = iter([f"ID{i}" for i in range(1, 7)])
        with patch.object(pgs, "list_all", return_value=[]), patch.object(
            pgs, "api_json", side_effect=lambda *args: {"id": next(new_ids)}
        ) as post:
            ids = pgs.inspect_resources("123456789012", "dummy", apply=True)
        self.assertEqual(ids["PLAY_GAMES_APP_ID"], "123456789012")
        self.assertEqual(len(ids), 7)
        self.assertEqual(post.call_count, 6)
        self.assertEqual(ids["PGS_FIRST_WIN_ID"], "ID1")
        self.assertEqual(ids["PGS_ONLINE_WINS_LEADERBOARD_ID"], "ID6")

    def test_reuses_existing_resources_without_mutation(self):
        achievements = [
            resource(name, f"existing{i}", kind="STANDARD")
            for i, (name, _, _, _) in enumerate(pgs.ACHIEVEMENTS, 1)
        ]
        boards = [resource("Online Wins", "existing6", score_order="LARGER_IS_BETTER")]
        with patch.object(pgs, "list_all", side_effect=[achievements, boards]), patch.object(
            pgs, "api_json"
        ) as post:
            ids = pgs.inspect_resources("123456789012", "dummy", apply=True)
        self.assertEqual(len(ids), 7)
        self.assertEqual(ids["PGS_TEN_WINS_ID"], "existing3")
        post.assert_not_called()

    def test_dry_run_creates_nothing(self):
        with patch.object(pgs, "list_all", return_value=[]), patch.object(pgs, "api_json") as post:
            ids = pgs.inspect_resources("123456789012", "dummy", apply=False)
        self.assertEqual(ids, {"PLAY_GAMES_APP_ID": "123456789012"})
        post.assert_not_called()

    def test_duplicate_resource_is_rejected(self):
        duplicates = [resource("First Win", "a", kind="STANDARD"),
                      resource("First Win", "b", kind="STANDARD")]
        with patch.object(pgs, "list_all", side_effect=[duplicates, []]):
            with self.assertRaisesRegex(RuntimeError, "Multiple"):
                pgs.inspect_resources("123456789012", "dummy", apply=True)


if __name__ == "__main__":
    unittest.main()
