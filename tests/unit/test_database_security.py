import unittest
from datetime import datetime, timedelta, timezone

from cloudcart.db import (
    DatabaseUsers,
    SecretStore,
    assess_rpo,
    issue_iam_token,
    rotate_password,
    token_is_expired,
    RotationError,
)


class DatabaseSecurityTest(unittest.TestCase):
    def test_rotation_replaces_the_password_and_rejects_plaintext(self):
        store = SecretStore("original-password")
        database = DatabaseUsers()
        database.set_password("cloudcart_app", "original-password")
        current = rotate_password(store, database, "cloudcart_app")
        self.assertNotEqual(current, "original-password")
        self.assertFalse(database.authenticate("cloudcart_app", "original-password", tls=True))
        self.assertTrue(database.authenticate("cloudcart_app", current, tls=True))
        self.assertFalse(database.authenticate("cloudcart_app", current, tls=False))
        self.assertNotIn(current, repr(database.log))

    def test_iam_user_is_not_the_rotated_password_user(self):
        database = DatabaseUsers()
        database.enable_iam("cloudcart_iam")
        token = issue_iam_token("cloudcart_iam")
        self.assertTrue(database.authenticate("cloudcart_iam", token, tls=True))
        self.assertFalse(database.authenticate("cloudcart_iam", token, tls=False))
        with self.assertRaises(RotationError):
            rotate_password(SecretStore("unused"), database, "cloudcart_iam")

    def test_iam_token_lifetime_is_fifteen_minutes(self):
        issued = datetime(2026, 11, 17, 12, 0, tzinfo=timezone.utc)
        self.assertFalse(token_is_expired(issued, issued + timedelta(minutes=14)))
        self.assertTrue(token_is_expired(issued, issued + timedelta(minutes=15)))

    def test_rpo_target_is_not_reported_as_an_rds_restore(self):
        now = datetime(2026, 11, 17, 12, 0, tzinfo=timezone.utc)
        inside = assess_rpo(now - timedelta(minutes=4), now)
        outside = assess_rpo(now - timedelta(minutes=6), now)
        self.assertTrue(inside["within_target"])
        self.assertFalse(outside["within_target"])
        self.assertFalse(inside["verified_against_rds"])
        self.assertEqual(inside["label"], "SIMULATED")


if __name__ == "__main__":
    unittest.main()
