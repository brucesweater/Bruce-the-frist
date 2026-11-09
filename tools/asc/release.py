"""Release commands for Unhook's App Store listing: metadata, age rating, review details, price, availability,
screenshots, the in-app event, attaching a build and submitting for review. Imported by asc.py.

Inputs live in the repository:
  AppStore/metadata/<locale>/{name,subtitle,keywords,description,promotional_text,support_url,marketing_url,privacy_url}.txt
  AppStore/metadata/{copyright,primary_category,secondary_category}.txt, AppStore/metadata/review_information/notes.txt
  AppStore/screenshots/final/<locale>/<display type>/*.png      (e.g. APP_IPHONE_67 = 1320 x 2868)
  AppStore/event/event.json and AppStore/event/<locale>/{card,details}.png
Nothing here prints personal data: the Actions logs of this repository are public.
"""
import hashlib
import json
import os
import time

import requests

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
METADATA = os.path.join(ROOT, "AppStore", "metadata")
SCREENSHOTS = os.path.join(ROOT, "AppStore", "screenshots", "final")
EVENT_DIR = os.path.join(ROOT, "AppStore", "event")
LOCALES = ["en-US", "es-MX", "pt-BR", "fr-FR", "de-DE", "it", "ja", "ko", "zh-Hans", "zh-Hant", "ru", "tr", "ar-SA",
           "hi", "id", "nl-NL"]
EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
# Territories left out of availability: mainland China needs an ICP filing number before distribution.
EXCLUDED_TERRITORIES = {"CHN"}

AGE_RATING = {
    # Unhook names habits such as smoking, drinking, cannabis, gambling and porn as things to quit, and shows
    # health information (the recovery timeline). No user-generated content, chat, ads or web access.
    "advertising": False,
    "ageAssurance": False,
    "alcoholTobaccoOrDrugUseOrReferences": "INFREQUENT_OR_MILD",
    "contests": "NONE",
    "gambling": False,
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "NONE",
    "healthOrWellnessTopics": True,
    "horrorOrFearThemes": "NONE",
    "lootBox": False,
    "matureOrSuggestiveThemes": "INFREQUENT_OR_MILD",
    "medicalOrTreatmentInformation": "INFREQUENT_OR_MILD",
    "messagingAndChat": False,
    "parentalControls": False,
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "socialMedia": False,
    "unrestrictedWebAccess": False,
    "userGeneratedContent": False,
    "violenceCartoonOrFantasy": "NONE",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
}


def _read(*parts):
    path = os.path.join(METADATA, *parts)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        text = handle.read().strip()
    return None if not text or "REPLACE_ME" in text else text


def _locales_present():
    return [loc for loc in LOCALES if _read(loc, "name.txt")]


def require_app(api):
    app = api.app()
    if not app:
        raise SystemExit("Unhook's app record doesn't exist yet: create it in App Store Connect first.")
    return app


def editable_app_info(api, app_id):
    infos = api.request("GET", f"/v1/apps/{app_id}/appInfos").get("data", [])
    for info in infos:
        if info["attributes"].get("state") not in ("READY_FOR_DISTRIBUTION",) and \
                info["attributes"].get("appStoreState") not in ("READY_FOR_SALE",):
            return info
    return infos[0]


def editable_version(api, app_id):
    versions = api.get_all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})
    for version in versions:
        state = version["attributes"].get("appStoreState") or version["attributes"].get("appVersionState")
        if state in EDITABLE_STATES or version["attributes"].get("appVersionState") in ("PREPARE_FOR_SUBMISSION",):
            return version
    raise SystemExit("No editable App Store version (one in Prepare for Submission) was found.")


def _upsert_localizations(api, list_path, create_type, parent_key, parent_type, parent_id, locale_attrs):
    existing = {loc["attributes"]["locale"]: loc for loc in api.request("GET", list_path).get("data", [])}
    for locale, attrs in locale_attrs.items():
        attrs = {k: v for k, v in attrs.items() if v is not None}
        if not attrs:
            continue
        if locale in existing:
            loc_id = existing[locale]["id"]
            api.request("PATCH", f"/v1/{create_type}/{loc_id}", body={"data": {
                "type": create_type, "id": loc_id, "attributes": attrs}})
            print(f"  updated {create_type} {locale}: {', '.join(sorted(attrs))}")
        else:
            api.request("POST", f"/v1/{create_type}", body={"data": {
                "type": create_type,
                "attributes": dict(locale=locale, **attrs),
                "relationships": {parent_key: {"data": {"type": parent_type, "id": parent_id}}},
            }})
            print(f"  created {create_type} {locale}: {', '.join(sorted(attrs))}")


def cmd_metadata(api):
    app = require_app(api)
    app_id = app["id"]
    info = editable_app_info(api, app_id)
    relationships = {}
    for key, filename in (("primaryCategory", "primary_category.txt"), ("secondaryCategory", "secondary_category.txt")):
        value = _read(filename)
        if value:
            relationships[key] = {"data": {"type": "appCategories", "id": value}}
    if relationships:
        api.request("PATCH", f"/v1/appInfos/{info['id']}", body={"data": {
            "type": "appInfos", "id": info["id"], "relationships": relationships}})
        print("Categories:", {k: v["data"]["id"] for k, v in relationships.items()})
    privacy_default = _read("en-US", "privacy_url.txt")
    _upsert_localizations(
        api, f"/v1/appInfos/{info['id']}/appInfoLocalizations", "appInfoLocalizations", "appInfo", "appInfos",
        info["id"], {loc: {
            "name": _read(loc, "name.txt"),
            "subtitle": _read(loc, "subtitle.txt"),
            "privacyPolicyUrl": _read(loc, "privacy_url.txt") or privacy_default,
        } for loc in _locales_present()})
    version = editable_version(api, app_id)
    attrs = {"releaseType": "AFTER_APPROVAL"}
    if _read("copyright.txt"):
        attrs["copyright"] = _read("copyright.txt")
    api.request("PATCH", f"/v1/appStoreVersions/{version['id']}", body={"data": {
        "type": "appStoreVersions", "id": version["id"], "attributes": attrs}})
    print(f"Version {version['attributes'].get('versionString')}: {attrs}")
    support_default = _read("en-US", "support_url.txt")
    marketing_default = _read("en-US", "marketing_url.txt")
    _upsert_localizations(
        api, f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations", "appStoreVersionLocalizations",
        "appStoreVersion", "appStoreVersions", version["id"], {loc: {
            "description": _read(loc, "description.txt"),
            "keywords": _read(loc, "keywords.txt"),
            "promotionalText": _read(loc, "promotional_text.txt"),
            "supportUrl": _read(loc, "support_url.txt") or support_default,
            "marketingUrl": _read(loc, "marketing_url.txt") or marketing_default,
        } for loc in _locales_present()})
    api.request("PATCH", f"/v1/apps/{app_id}", body={"data": {
        "type": "apps", "id": app_id, "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    print("Content rights: does not use third-party content.")


def cmd_age_rating(api):
    app = require_app(api)
    info = editable_app_info(api, app["id"])
    declaration = api.request("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    api.request("PATCH", f"/v1/ageRatingDeclarations/{declaration['id']}", body={"data": {
        "type": "ageRatingDeclarations", "id": declaration["id"], "attributes": AGE_RATING}})
    refreshed = api.request("GET", f"/v1/apps/{app['id']}/appInfos").get("data", [])
    for item in refreshed:
        print("Age rating:", item["attributes"].get("appStoreAgeRating"), "| state", item["attributes"].get("state"))


def _review_contact(api):
    """Copies the App Review contact from Bruce Run (same developer), without printing it."""
    source = api.app("com.brucegao.brucerun")
    if not source:
        return {}
    versions = api.get_all(f"/v1/apps/{source['id']}/appStoreVersions", {"filter[platform]": "IOS"})
    for version in versions:
        try:
            detail = api.request("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
        except Exception:  # noqa: BLE001 - a version without review details
            continue
        if detail:
            attrs = detail["attributes"]
            contact = {k: attrs.get(k) for k in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")}
            if all(contact.values()):
                return contact
    return {}


def cmd_review_details(api):
    app = require_app(api)
    version = editable_version(api, app["id"])
    attrs = dict(_review_contact(api))
    if os.environ.get("REVIEW_PHONE"):
        attrs["contactPhone"] = os.environ["REVIEW_PHONE"]
    attrs["demoAccountRequired"] = False
    notes = _read("review_information", "notes.txt")
    if notes:
        attrs["notes"] = notes[:3900]
    try:
        existing = api.request("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    except Exception:  # noqa: BLE001 - none yet
        existing = None
    if existing:
        api.request("PATCH", f"/v1/appStoreReviewDetails/{existing['id']}", body={"data": {
            "type": "appStoreReviewDetails", "id": existing["id"], "attributes": attrs}})
    else:
        api.request("POST", "/v1/appStoreReviewDetails", body={"data": {
            "type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    print("Review details set:", sorted(k for k, v in attrs.items() if v not in (None, "")),
          "(contact copied from Bruce Run)" if attrs.get("contactEmail") else "(no contact found: add it on the website)")


def cmd_pricing(api):
    app = require_app(api)
    points = api.request("GET", f"/v1/apps/{app['id']}/appPricePoints",
                         params={"filter[territory]": "USA", "limit": 200}).get("data", [])
    free = next((p for p in points if float(p["attributes"].get("customerPrice") or 1) == 0), None)
    if not free:
        raise SystemExit("Couldn't find the free price point.")
    api.request("POST", "/v1/appPriceSchedules", body={
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app["id"]}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]},
        }},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}],
    })
    print("Price: free (base territory USA).")


def cmd_availability(api):
    app = require_app(api)
    territories = [t for t in api.get_all("/v1/territories") if t["id"] not in EXCLUDED_TERRITORIES]
    included = [{
        "type": "territoryAvailabilities", "id": "${" + t["id"] + "}", "attributes": {"available": True},
        "relationships": {"territory": {"data": {"type": "territories", "id": t["id"]}}},
    } for t in territories]
    try:
        api.request("POST", "/v2/appAvailabilities", body={
            "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True}, "relationships": {
                "app": {"data": {"type": "apps", "id": app["id"]}},
                "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": i["id"]} for i in included]},
            }},
            "included": included,
        })
        print(f"Available in {len(territories)} territories (mainland China needs an ICP filing first).")
    except Exception as error:  # noqa: BLE001
        print("Availability not changed:", str(error)[:600])


def _md5(data):
    return hashlib.md5(data).hexdigest()


def _upload_asset(api, create_type, attributes, relationships, data):
    created = api.request("POST", f"/v1/{create_type}", body={"data": {
        "type": create_type, "attributes": attributes, "relationships": relationships}})["data"]
    for op in created["attributes"].get("uploadOperations") or []:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders") or []}
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        response = requests.request(op["method"], op["url"], headers=headers, data=chunk, timeout=180)
        response.raise_for_status()
    api.request("PATCH", f"/v1/{create_type}/{created['id']}", body={"data": {
        "type": create_type, "id": created["id"], "attributes": {"uploaded": True, "sourceFileChecksum": _md5(data)}}})
    return created["id"]


def _wait_for_assets(api, create_type, ids, timeout=300):
    deadline = time.time() + timeout
    pending = set(ids)
    while pending and time.time() < deadline:
        for asset_id in list(pending):
            state = (api.request("GET", f"/v1/{create_type}/{asset_id}")["data"]["attributes"]
                     .get("assetDeliveryState") or {}).get("state")
            if state in ("COMPLETE", "FAILED"):
                pending.discard(asset_id)
                if state == "FAILED":
                    print(f"  {create_type} {asset_id} failed processing")
        if pending:
            time.sleep(4)
    if pending:
        print(f"  {len(pending)} {create_type} still processing")


def cmd_screenshots(api):
    app = require_app(api)
    version = editable_version(api, app["id"])
    locs = {loc["attributes"]["locale"]: loc for loc in api.request(
        "GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations").get("data", [])}
    if not os.path.isdir(SCREENSHOTS):
        raise SystemExit("No screenshots in AppStore/screenshots/final yet.")
    for locale in sorted(os.listdir(SCREENSHOTS)):
        if locale not in locs:
            print(f"Skipping {locale}: no version localization (run [asc metadata] first)")
            continue
        loc_id = locs[locale]["id"]
        sets = {s["attributes"]["screenshotDisplayType"]: s for s in api.request(
            "GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets").get("data", [])}
        for display_type in sorted(os.listdir(os.path.join(SCREENSHOTS, locale))):
            folder = os.path.join(SCREENSHOTS, locale, display_type)
            files = sorted(f for f in os.listdir(folder) if f.lower().endswith((".png", ".jpg", ".jpeg")))
            if not files:
                continue
            if display_type in sets:
                set_id = sets[display_type]["id"]
                for shot in api.request("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots").get("data", []):
                    api.request("DELETE", f"/v1/appScreenshots/{shot['id']}")
            else:
                set_id = api.request("POST", "/v1/appScreenshotSets", body={"data": {
                    "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {"appStoreVersionLocalization": {"data": {
                        "type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]["id"]
            ids = []
            for name in files:
                with open(os.path.join(folder, name), "rb") as handle:
                    data = handle.read()
                ids.append(_upload_asset(api, "appScreenshots", {"fileName": name, "fileSize": len(data)}, {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}, data))
            _wait_for_assets(api, "appScreenshots", ids)
            print(f"{locale} {display_type}: uploaded {len(ids)} screenshots")


def cmd_event(api):
    """Creates (or updates) the in-app event described in AppStore/event/event.json, with its images."""
    app = require_app(api)
    with open(os.path.join(EVENT_DIR, "event.json"), encoding="utf-8") as handle:
        spec = json.load(handle)
    territories = [t["id"] for t in api.get_all("/v1/territories") if t["id"] not in EXCLUDED_TERRITORIES]
    attributes = {
        "referenceName": spec["referenceName"],
        "badge": spec["badge"],
        "deepLink": spec["deepLink"],
        "purchaseRequirement": "NO_COST_ASSOCIATED",
        "primaryLocale": "en-US",
        "priority": spec.get("priority", "HIGH"),
        "purpose": spec.get("purpose", "APPROPRIATE_FOR_ALL_USERS"),
        "territorySchedules": [{
            "territories": territories,
            "publishStart": spec["publishStart"],
            "eventStart": spec["eventStart"],
            "eventEnd": spec["eventEnd"],
        }],
    }
    events = api.request("GET", f"/v1/apps/{app['id']}/appEvents", params={"limit": 50}).get("data", [])
    event = next((e for e in events if e["attributes"].get("referenceName") == spec["referenceName"]), None)
    if event:
        api.request("PATCH", f"/v1/appEvents/{event['id']}", body={"data": {
            "type": "appEvents", "id": event["id"], "attributes": attributes}})
        event_id = event["id"]
        print("Updated the in-app event", event_id)
    else:
        event_id = api.request("POST", "/v1/appEvents", body={"data": {
            "type": "appEvents", "attributes": attributes,
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]["id"]
        print("Created the in-app event", event_id)
    existing = {loc["attributes"]["locale"]: loc for loc in api.request(
        "GET", f"/v1/appEvents/{event_id}/localizations").get("data", [])}
    for locale, text in spec["localizations"].items():
        attrs = {"name": text["name"], "shortDescription": text["shortDescription"],
                 "longDescription": text["longDescription"]}
        if locale in existing:
            loc_id = existing[locale]["id"]
            api.request("PATCH", f"/v1/appEventLocalizations/{loc_id}", body={"data": {
                "type": "appEventLocalizations", "id": loc_id, "attributes": attrs}})
        else:
            loc_id = api.request("POST", "/v1/appEventLocalizations", body={"data": {
                "type": "appEventLocalizations", "attributes": dict(locale=locale, **attrs),
                "relationships": {"appEvent": {"data": {"type": "appEvents", "id": event_id}}}}})["data"]["id"]
        image_dir = os.path.join(EVENT_DIR, locale if os.path.isdir(os.path.join(EVENT_DIR, locale)) else "en-US")
        current = api.request("GET", f"/v1/appEventLocalizations/{loc_id}/appEventScreenshots").get("data", [])
        for shot in current:
            api.request("DELETE", f"/v1/appEventScreenshots/{shot['id']}")
        ids = []
        for asset_type, filename in (("EVENT_CARD", "card.png"), ("EVENT_DETAILS_PAGE", "details.png")):
            path = os.path.join(image_dir, filename)
            if not os.path.exists(path):
                continue
            with open(path, "rb") as handle:
                data = handle.read()
            ids.append(_upload_asset(api, "appEventScreenshots", {
                "fileName": filename, "fileSize": len(data), "appEventAssetType": asset_type}, {
                "appEventLocalization": {"data": {"type": "appEventLocalizations", "id": loc_id}}}, data))
        _wait_for_assets(api, "appEventScreenshots", ids)
        print(f"  {locale}: text and {len(ids)} images")


def _latest_valid_build(api, app_id):
    builds = api.request("GET", "/v1/builds", params={
        "filter[app]": app_id, "sort": "-uploadedDate", "limit": 10}).get("data", [])
    for build in builds:
        if build["attributes"].get("processingState") == "VALID" and not build["attributes"].get("expired"):
            return build
    return None


def cmd_attach_build(api):
    app = require_app(api)
    version = editable_version(api, app["id"])
    build = _latest_valid_build(api, app["id"])
    if not build:
        raise SystemExit("No processed build yet: upload one with [asc build] and wait for processing.")
    if build["attributes"].get("usesNonExemptEncryption") is None:
        api.request("PATCH", f"/v1/builds/{build['id']}", body={"data": {
            "type": "builds", "id": build["id"], "attributes": {"usesNonExemptEncryption": False}}})
    api.request("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build", body={"data": {
        "type": "builds", "id": build["id"]}})
    print(f"Attached build {build['attributes'].get('version')} to version {version['attributes'].get('versionString')}.")


def cmd_submit(api):
    app = require_app(api)
    version = editable_version(api, app["id"])
    open_states = ("READY_FOR_REVIEW",)
    subs = api.request("GET", "/v1/reviewSubmissions", params={
        "filter[app]": app["id"], "filter[platform]": "IOS"}).get("data", [])
    submission = next((s for s in subs if s["attributes"].get("state") in open_states), None)
    if not submission:
        submission = api.request("POST", "/v1/reviewSubmissions", body={"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]
    items = api.request("GET", f"/v1/reviewSubmissions/{submission['id']}/items").get("data", [])
    if not items:
        api.request("POST", "/v1/reviewSubmissionItems", body={"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
        events = api.request("GET", f"/v1/apps/{app['id']}/appEvents", params={"limit": 50}).get("data", [])
        for event in events:
            if event["attributes"].get("eventState") in ("DRAFT", "READY_FOR_REVIEW"):
                try:
                    api.request("POST", "/v1/reviewSubmissionItems", body={"data": {
                        "type": "reviewSubmissionItems", "relationships": {
                            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                            "appEvent": {"data": {"type": "appEvents", "id": event["id"]}}}}})
                    print("Added the in-app event", event["attributes"].get("referenceName"))
                except Exception as error:  # noqa: BLE001
                    print("Couldn't add the in-app event:", str(error)[:400])
    api.request("PATCH", f"/v1/reviewSubmissions/{submission['id']}", body={"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}})
    print("Submitted for App Review.")


def cmd_status(api):
    app = require_app(api)
    for version in api.get_all(f"/v1/apps/{app['id']}/appStoreVersions", {"filter[platform]": "IOS"})[:3]:
        attrs = version["attributes"]
        print(f"Version {attrs.get('versionString')}: {attrs.get('appStoreState')} / {attrs.get('appVersionState')}")
    build = _latest_valid_build(api, app["id"])
    print("Latest processed build:", build["attributes"].get("version") if build else None)
    subs = api.request("GET", "/v1/reviewSubmissions", params={"filter[app]": app["id"]}).get("data", [])
    for sub in subs[:3]:
        print("Review submission:", sub["attributes"].get("state"), sub["attributes"].get("submittedDate"))
    for info in api.request("GET", f"/v1/apps/{app['id']}/appInfos").get("data", []):
        print("Age rating:", info["attributes"].get("appStoreAgeRating"), "| app info state", info["attributes"].get("state"))


COMMANDS = {
    "metadata": cmd_metadata,
    "age-rating": cmd_age_rating,
    "review-details": cmd_review_details,
    "pricing": cmd_pricing,
    "availability": cmd_availability,
    "screenshots": cmd_screenshots,
    "event": cmd_event,
    "attach-build": cmd_attach_build,
    "submit": cmd_submit,
    "status": cmd_status,
}
