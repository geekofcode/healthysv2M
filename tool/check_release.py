#!/usr/bin/env python3
"""Validate deployment inputs without printing configuration values or secrets."""
import argparse
import json
import plistlib
import re
from pathlib import Path
from urllib.parse import urlsplit


def production_url(value, *, api=False):
    if not isinstance(value, str):
        return False
    try:
        parsed = urlsplit(value)
        host = parsed.hostname or ""
        parsed.port  # Reject invalid ports.
    except ValueError:
        return False
    placeholder = any(host == name or host.endswith("." + name) for name in
                      ("example.com", "example.org", "example.net", "localhost", "invalid", "test"))
    return (parsed.scheme == "https" and bool(host) and not placeholder
            and not parsed.username and not parsed.password
            and not parsed.query and not parsed.fragment
            and (not api or parsed.path.rstrip("/").endswith("/api/v1")))


def check_config(config):
    errors = []
    if config.get("APP_ENV") != "prod":
        errors.append("APP_ENV doit valoir prod.")
    if not production_url(config.get("API_BASE_URL"), api=True):
        errors.append("API_BASE_URL exige une URL HTTPS de production terminant par /api/v1.")
    if not production_url(config.get("OIDC_ISSUER")):
        errors.append("OIDC_ISSUER exige un issuer HTTPS de production.")
    if not isinstance(config.get("OIDC_CLIENT_ID"), str) or not config["OIDC_CLIENT_ID"].strip():
        errors.append("OIDC_CLIENT_ID public obligatoire.")
    for key in ("OIDC_REDIRECT_URI", "OIDC_POST_LOGOUT_REDIRECT_URI"):
        if config.get(key) != "healthys://oauth/callback":
            errors.append(f"{key} doit correspondre au callback natif enregistré.")
    for key in config:
        if re.search(r"SECRET|PRIVATE.?KEY|PASSWORD|SERVICE.?ACCOUNT|ACCESS.?TOKEN|REFRESH.?TOKEN", key, re.I):
            errors.append("Un champ secret interdit est présent dans les dart-defines.")
            break
    if not isinstance(config.get("PUSH_ENABLED", False), bool):
        errors.append("PUSH_ENABLED doit être un booléen JSON.")
    if config.get("PUSH_ENABLED") is True:
        for key in ("FIREBASE_API_KEY", "FIREBASE_APP_ID", "FIREBASE_MESSAGING_SENDER_ID", "FIREBASE_PROJECT_ID"):
            if not isinstance(config.get(key), str) or not config[key].strip():
                errors.append(f"{key} obligatoire lorsque le push est activé.")
    return errors


def check_native(root, platform, config):
    errors = []
    if platform == "android":
        text = (root / "android/app/build.gradle.kts").read_text()
        match = re.search(r'applicationId\s*=\s*"([^"]+)"', text)
        identifier = match[1] if match else ""
        signing = root / "android/key.properties"
        if not signing.is_file():
            errors.append("Signature release Android : android/key.properties absent.")
        else:
            properties = dict(line.split("=", 1) for line in signing.read_text().splitlines()
                              if "=" in line and not line.lstrip().startswith("#"))
            if any(not properties.get(key, "").strip() for key in
                   ("storeFile", "storePassword", "keyAlias", "keyPassword")):
                errors.append("Configuration de signature Android incomplète.")
            elif not (root / "android" / properties["storeFile"].strip()).is_file():
                errors.append("Keystore Android absent.")
        if config.get("PUSH_ENABLED") is True:
            try:
                firebase = json.loads((root / "android/app/google-services.json").read_text())
                clients = [item for item in firebase["client"] if
                           item["client_info"]["android_client_info"]["package_name"] == identifier]
                project = firebase["project_info"]
                if (not clients or project["project_id"] != config["FIREBASE_PROJECT_ID"]
                        or str(project["project_number"]) != config["FIREBASE_MESSAGING_SENDER_ID"]
                        or not any(item["client_info"]["mobilesdk_app_id"] == config["FIREBASE_APP_ID"]
                                   and any(k["current_key"] == config["FIREBASE_API_KEY"] for k in item.get("api_key", []))
                                   for item in clients)):
                    errors.append("Firebase Android ne correspond pas à l'identifiant ou aux dart-defines.")
            except (OSError, ValueError, KeyError, TypeError):
                errors.append("Configuration Firebase Android absente ou invalide.")
    else:
        text = (root / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        identifiers = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", text)
        identifiers = {value.strip().strip('"') for value in identifiers if "RunnerTests" not in value}
        identifier = next(iter(identifiers)) if len(identifiers) == 1 else ""
        if not re.search(r"DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]{10}\s*;", text):
            errors.append("Équipe Apple DEVELOPMENT_TEAM non configurée dans Runner.")
        if config.get("PUSH_ENABLED") is True:
            try:
                firebase = plistlib.loads((root / "ios/Runner/GoogleService-Info.plist").read_bytes())
                mappings = {"PROJECT_ID": "FIREBASE_PROJECT_ID", "GOOGLE_APP_ID": "FIREBASE_APP_ID",
                            "GCM_SENDER_ID": "FIREBASE_MESSAGING_SENDER_ID", "API_KEY": "FIREBASE_API_KEY"}
                if (firebase["BUNDLE_ID"] != identifier or config.get("FIREBASE_IOS_BUNDLE_ID") != identifier
                        or any(str(firebase[k]) != config[v] for k, v in mappings.items())):
                    errors.append("Firebase iOS ne correspond pas à l'identifiant ou aux dart-defines.")
            except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException):
                errors.append("Configuration Firebase iOS absente ou invalide.")
    if not identifier or identifier.startswith("com.example.") or "$" in identifier:
        errors.append("Remplacer l'identifiant exemple par l'identifiant enregistré sur le store.")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("android", "ios"), required=True)
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        config = json.loads(args.config.read_text())
        if not isinstance(config, dict):
            raise ValueError()
        errors = check_config(config)
        errors.extend(check_native(root, args.platform, config))
    except (OSError, ValueError, TypeError):
        errors = ["Configuration de publication absente ou invalide."]
    for error in errors:
        print(error)
    if not errors:
        print("Prévalidation réussie. Vérifier les certificats, les stores et les appareils avant distribution.")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
