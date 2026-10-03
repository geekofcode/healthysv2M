import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("release", Path(__file__).parents[1] / "check_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseConfigurationTests(unittest.TestCase):
    def config(self):
        return {"APP_ENV": "prod", "API_BASE_URL": "https://api.healthys.fr/api/v1",
                "OIDC_ISSUER": "https://identity.healthys.fr/realms/healthys",
                "OIDC_CLIENT_ID": "healthys-mobile", "OIDC_REDIRECT_URI": "healthys://oauth/callback",
                "OIDC_POST_LOGOUT_REDIRECT_URI": "healthys://oauth/callback", "PUSH_ENABLED": False}

    def test_real_public_config_is_accepted(self):
        self.assertEqual([], release.check_config(self.config()))

    def test_placeholder_and_credential_urls_are_rejected(self):
        for url in ("https://api.example.com/api/v1", "http://api.healthys.fr/api/v1",
                    "https://user:pass@api.healthys.fr/api/v1", "https://api.healthys.fr/api/v1?token=x",
                    "https://api.healthys.fr/api/v1#x", "https://api.healthys.fr:bad/api/v1"):
            with self.subTest(url=url):
                self.assertFalse(release.production_url(url, api=True))

    def test_secret_fields_are_rejected_without_printing_their_values(self):
        config = self.config() | {"OIDC_CLIENT_SECRET": "sensitive-content"}
        errors = release.check_config(config)
        self.assertTrue(errors)
        self.assertNotIn("sensitive-content", str(errors))

    def test_push_requires_typed_flag_and_complete_ids(self):
        self.assertTrue(release.check_config(self.config() | {"PUSH_ENABLED": "false"}))
        self.assertTrue(release.check_config(self.config() | {"PUSH_ENABLED": True}))

    def test_android_rejects_default_identifier_and_missing_signature(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "android/app").mkdir(parents=True)
            (root / "android/app/build.gradle.kts").write_text('applicationId = "com.example.healthysv2"')
            self.assertEqual(2, len(release.check_native(root, "android", self.config())))

    def test_android_signature_and_registered_id_require_existing_key(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "android/app").mkdir(parents=True)
            (root / "android/app/build.gradle.kts").write_text('applicationId = "fr.healthys.patient"')
            (root / "android/key.properties").write_text('storeFile=upload.jks\nstorePassword=x\nkeyAlias=x\nkeyPassword=x\n')
            self.assertTrue(release.check_native(root, "android", self.config()))
            (root / "android/upload.jks").write_bytes(b"test-fixture")
            self.assertEqual([], release.check_native(root, "android", self.config()))

    def test_ios_requires_registered_identifier_and_team(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "ios/Runner.xcodeproj").mkdir(parents=True)
            project = root / "ios/Runner.xcodeproj/project.pbxproj"
            project.write_text('PRODUCT_BUNDLE_IDENTIFIER = com.example.healthysv2;')
            self.assertEqual(2, len(release.check_native(root, "ios", self.config())))
            project.write_text('PRODUCT_BUNDLE_IDENTIFIER = fr.healthys.patient; DEVELOPMENT_TEAM = ABC1234567;')
            self.assertEqual([], release.check_native(root, "ios", self.config()))


if __name__ == "__main__":
    unittest.main()
