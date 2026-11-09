#!/usr/bin/env python3
"""A small App Store Connect API client for Unhook's release automation. Runs in GitHub Actions.

Credentials come from the environment: ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY (the contents of the .p8 file,
stored as a repository secret). The Actions logs of this public repository are public, so this script never prints
secrets or personal data such as phone numbers.

Usage:
  asc.py check                     verify the key; list apps, bundle IDs and the team ID
  asc.py register                  register Unhook's bundle IDs and turn on App Groups
  asc.py app                       print Unhook's app record (after it is created on the website)
  asc.py from-commit-message       run the commands named in COMMIT_MESSAGE as "[asc <command>]"
"""
import json
import os
import re
import sys
import time

import jwt
import requests

BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_PREFIX = os.environ.get("UNHOOK_BUNDLE_PREFIX", "com.bruce.unhook")
BUNDLES = [
    (BUNDLE_PREFIX, "Unhook"),
    (BUNDLE_PREFIX + ".widgets", "Unhook Widgets"),
]


class APIError(Exception):
    def __init__(self, method, path, status, body):
        super().__init__(f"{method} {path} -> {status}: {body[:1500]}")
        self.status = status
        self.body = body


def normalized_private_key(raw):
    """Accepts the .p8 contents however they were pasted (CRLF, missing newlines, surrounding spaces)."""
    key = raw.replace("\r\n", "\n").replace("\r", "\n").strip()
    match = re.search(r"-----BEGIN PRIVATE KEY-----(.*?)-----END PRIVATE KEY-----", key, re.S)
    if not match:
        raise SystemExit("ASC_PRIVATE_KEY doesn't look like a .p8 key (no BEGIN/END PRIVATE KEY lines).")
    body = re.sub(r"\s+", "", match.group(1))
    lines = [body[i:i + 64] for i in range(0, len(body), 64)]
    return "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----\n"


class ASC:
    def __init__(self):
        missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY") if not os.environ.get(name)]
        if missing:
            raise SystemExit("Missing " + ", ".join(missing) + ". Add the ASC_PRIVATE_KEY repository secret.")
        self.key_id = os.environ["ASC_KEY_ID"].strip()
        self.issuer_id = os.environ["ASC_ISSUER_ID"].strip()
        self.private_key = normalized_private_key(os.environ["ASC_PRIVATE_KEY"])
        self._token = None
        self._expires = 0

    def token(self):
        now = int(time.time())
        if self._token is None or now > self._expires - 60:
            self._expires = now + 15 * 60
            self._token = jwt.encode(
                {"iss": self.issuer_id, "iat": now, "exp": self._expires, "aud": "appstoreconnect-v1"},
                self.private_key,
                algorithm="ES256",
                headers={"kid": self.key_id, "typ": "JWT"},
            )
        return self._token

    def request(self, method, path, params=None, body=None):
        url = path if path.startswith("http") else BASE + path
        response = None
        for attempt in range(5):
            response = requests.request(
                method, url, params=params,
                data=None if body is None else json.dumps(body),
                headers={"Authorization": "Bearer " + self.token(), "Content-Type": "application/json"},
                timeout=90,
            )
            if response.status_code in (429, 500, 502, 503, 504):
                time.sleep(3 * (attempt + 1))
                continue
            break
        if response.status_code >= 400:
            raise APIError(method, path, response.status_code, response.text)
        return response.json() if response.content else {}

    def get_all(self, path, params=None):
        items, url, query = [], path, dict(params or {})
        query.setdefault("limit", 200)
        while url:
            page = self.request("GET", url, params=query)
            items.extend(page.get("data", []))
            url = page.get("links", {}).get("next")
            query = None  # the next link already carries the query
        return items

    def bundle_id(self, identifier):
        found = self.get_all("/v1/bundleIds", {"filter[identifier]": identifier})
        return next((b for b in found if b["attributes"]["identifier"] == identifier), None)

    def app(self, bundle_identifier=BUNDLE_PREFIX):
        found = self.get_all("/v1/apps", {"filter[bundleId]": bundle_identifier})
        return next((a for a in found if a["attributes"]["bundleId"] == bundle_identifier), None)


def cmd_check(api):
    apps = api.get_all("/v1/apps")
    print(f"The API key works. {len(apps)} app(s) on this team:")
    for a in apps:
        attrs = a["attributes"]
        print(f"  - {attrs.get('name')} | {attrs.get('bundleId')} | sku {attrs.get('sku')} | "
              f"{attrs.get('primaryLocale')} | id {a['id']}")
    bundles = api.get_all("/v1/bundleIds")
    teams = sorted({b["attributes"].get("seedId") for b in bundles if b["attributes"].get("seedId")})
    print(f"{len(bundles)} bundle ID(s). Team ID(s): {', '.join(teams) or 'unknown'}")
    for b in bundles:
        attrs = b["attributes"]
        print(f"  - {attrs['identifier']} | {attrs['name']} | {attrs['platform']}")
    for identifier, _ in BUNDLES:
        print(f"{identifier}: {'registered' if api.bundle_id(identifier) else 'not registered yet'}")
    certs = api.get_all("/v1/certificates")
    kinds = {}
    for c in certs:
        kinds[c["attributes"]["certificateType"]] = kinds.get(c["attributes"]["certificateType"], 0) + 1
    print("Certificates by type:", json.dumps(kinds, sort_keys=True))
    app = api.app()
    print("Unhook app record:", f"exists (id {app['id']})" if app else "not created yet")


def cmd_register(api):
    for identifier, name in BUNDLES:
        existing = api.bundle_id(identifier)
        if existing:
            print(f"{identifier} is already registered (id {existing['id']}).")
            bundle_pk = existing["id"]
        else:
            created = api.request("POST", "/v1/bundleIds", body={"data": {
                "type": "bundleIds",
                "attributes": {"identifier": identifier, "name": name, "platform": "IOS"},
            }})
            bundle_pk = created["data"]["id"]
            print(f"Registered {identifier} (id {bundle_pk}).")
        capabilities = api.get_all(f"/v1/bundleIds/{bundle_pk}/bundleIdCapabilities")
        if any(c["attributes"]["capabilityType"] == "APP_GROUPS" for c in capabilities):
            print(f"  App Groups is already on for {identifier}.")
            continue
        try:
            api.request("POST", "/v1/bundleIdCapabilities", body={"data": {
                "type": "bundleIdCapabilities",
                "attributes": {"capabilityType": "APP_GROUPS"},
                "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_pk}}},
            }})
            print(f"  Turned on App Groups for {identifier}.")
        except APIError as error:
            print(f"  Couldn't turn on App Groups for {identifier}: {error}")


def cmd_app(api):
    app = api.app()
    if not app:
        print(f"No app record for {BUNDLE_PREFIX} yet. Create it in App Store Connect (Apps > + > New App).")
        return
    attrs = app["attributes"]
    print(f"Unhook app record: {attrs.get('name')} | {attrs.get('bundleId')} | sku {attrs.get('sku')} | id {app['id']}")
    versions = api.get_all(f"/v1/apps/{app['id']}/appStoreVersions")
    for v in versions:
        va = v["attributes"]
        print(f"  version {va.get('versionString')} | {va.get('appStoreState') or va.get('appVersionState')} | id {v['id']}")


COMMANDS = {"check": cmd_check, "register": cmd_register, "app": cmd_app}


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    command = argv[1]
    if command == "from-commit-message":
        message = os.environ.get("COMMIT_MESSAGE", "")
        names = re.findall(r"\[asc ([a-z-]+)\]", message)
        names = [n for n in names if n in COMMANDS]
        if not names:
            print("No App Store Connect API command in the commit message.")
            return 0
    else:
        names = [command]
    api = ASC()
    failed = False
    for name in names:
        print(f"== {name}")
        try:
            COMMANDS[name](api)
        except APIError as error:
            failed = True
            print(f"FAILED: {error}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
