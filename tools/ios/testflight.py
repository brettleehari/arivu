#!/usr/bin/env python3
"""TestFlight from the command line: build status, groups, testers, external submission.

WHY THIS EXISTS. Both TestFlight routes are a sequence of clicks in App Store Connect, and the
sequence is easy to get subtly wrong under a deadline — a group without a build attached, an
external submission missing the review contact, a tester invited to a build still processing. Each
of those looks like it worked and fails on someone else's phone.

NO DEPENDENCIES ON PURPOSE. This machine has no PyJWT, no `cryptography` and no fastlane, and a
release tool that needs `pip install` on the day is not a release tool. The ES256 signature is made
by openssl and converted from DER to the raw r||s form the JWT spec wants, in about fifteen lines
below. Standard library plus openssl plus curl, all of which are already here.

CREDENTIALS. App Store Connect > Users and Access > Integrations > App Store Connect API > +
(App Manager is enough). Download AuthKey_<KEYID>.p8 ONCE — Apple will not let you download it
again — and put it in ~/.appstoreconnect/private_keys/. Then:

    export ASC_KEY_ID=...      # the 10-character key id
    export ASC_ISSUER_ID=...   # the uuid shown above the key list

Usage:
    tools/ios/testflight.py status
    tools/ios/testflight.py groups
    tools/ios/testflight.py internal "Demo"                      # create/attach, then add users in ASC
    tools/ios/testflight.py prepare "Hari S" "+44..."             # app-level fields review needs
    tools/ios/testflight.py external "Friends" a@x.com b@y.com   # create, attach, invite, submit
    tools/ios/testflight.py whats-new                            # push What to Test from the Leaf

UNVERIFIED: written before any API key existed, so no call below has been made against the live
service. Treat the first run as the test.

spine: C1
"""
import base64, json, os, pathlib, subprocess, sys, time, urllib.error, urllib.request

BUNDLE_ID = "io.github.brettleehari.arivu"
API = "https://api.appstoreconnect.apple.com"
ROOT = pathlib.Path(__file__).resolve().parents[2]


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """An ECDSA signature from openssl is DER; a JWT wants the bare r||s, 32 bytes each.

    DER here is 30 <len> 02 <rlen> <r> 02 <slen> <s>, and r/s carry a leading zero byte whenever
    their top bit is set, so they need stripping and re-padding rather than copying.
    """
    if der[0] != 0x30:
        die("openssl did not return a DER signature")
    i = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    out = b""
    for _ in range(2):
        if der[i] != 0x02:
            die("malformed DER signature")
        length = der[i + 1]
        val = der[i + 2 : i + 2 + length].lstrip(b"\x00")
        out += val.rjust(32, b"\x00")
        i += 2 + length
    return out


def token() -> str:
    key_id = os.environ.get("ASC_KEY_ID")
    issuer = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer:
        die("set ASC_KEY_ID and ASC_ISSUER_ID (see the header of this file)")
    keys = list(pathlib.Path.home().glob(f".appstoreconnect/private_keys/AuthKey_{key_id}.p8"))
    if not keys:
        die(f"no AuthKey_{key_id}.p8 in ~/.appstoreconnect/private_keys/")

    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    # Apple rejects anything longer than 20 minutes.
    payload = {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64(json.dumps(header).encode())}.{b64(json.dumps(payload).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(keys[0])],
                         input=signing_input.encode(), capture_output=True).stdout
    if not der:
        die("openssl could not sign with that key")
    return f"{signing_input}.{b64(der_to_raw(der))}"


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body else None)
    req.add_header("Authorization", "Bearer " + token())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            for err in json.loads(detail).get("errors", []):
                print(f"  {err.get('title')}: {err.get('detail')}", file=sys.stderr)
        except Exception:
            print(detail[:600], file=sys.stderr)
        die(f"{method} {path} -> HTTP {e.code}")


def app_id():
    data = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if not data.get("data"):
        die(f"no app with bundle id {BUNDLE_ID} — create the app record first")
    return data["data"][0]["id"]


def builds(aid):
    return call("GET", f"/v1/builds?filter[app]={aid}&limit=10&sort=-uploadedDate"
                       f"&include=preReleaseVersion")["data"]


def newest_build(aid):
    for b in builds(aid):
        if b["attributes"]["processingState"] == "VALID":
            return b
    die("no build has finished processing yet — check `status`")


def find_group(aid, name):
    for g in call("GET", f"/v1/betaGroups?filter[app]={aid}&limit=200")["data"]:
        if g["attributes"]["name"] == name:
            return g
    return None


def ensure_group(aid, name, internal):
    g = find_group(aid, name)
    if g:
        print(f"   group '{name}' already exists")
        return g["id"]
    g = call("POST", "/v1/betaGroups", {"data": {
        "type": "betaGroups",
        "attributes": {"name": name, "isInternalGroup": internal,
                       **({} if internal else {"publicLinkEnabled": False})},
        "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
    print(f"   created {'internal' if internal else 'external'} group '{name}'")
    return g["data"]["id"]


def attach_build(gid, bid):
    call("POST", f"/v1/betaGroups/{gid}/relationships/builds",
         {"data": [{"type": "builds", "id": bid}]})
    print("   build attached")


def whats_new_text():
    """The What to Test block, read from the Leaf rather than typed twice."""
    md = (ROOT / "leaves/gtm/testflight-beta.md").read_text()
    marker = "## What to Test"
    if marker not in md:
        die("no '## What to Test' section in leaves/gtm/testflight-beta.md")
    body = md.split(marker, 1)[1]
    return body.split("```text", 1)[1].split("```", 1)[0].strip()


def set_whats_new(bid):
    text = whats_new_text()
    existing = call("GET", f"/v1/builds/{bid}/betaBuildLocalizations")["data"]
    for loc in existing:
        if loc["attributes"]["locale"].startswith("en"):
            call("PATCH", f"/v1/betaBuildLocalizations/{loc['id']}",
                 {"data": {"type": "betaBuildLocalizations", "id": loc["id"],
                           "attributes": {"whatsNew": text}}})
            print(f"   what-to-test set ({len(text)} chars, {loc['attributes']['locale']})")
            return
    call("POST", "/v1/betaBuildLocalizations", {"data": {
        "type": "betaBuildLocalizations",
        "attributes": {"locale": "en-US", "whatsNew": text},
        "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
    print(f"   what-to-test created ({len(text)} chars)")


def add_testers(gid, emails):
    for e in emails:
        first, _, last = e.split("@")[0].partition(".")
        try:
            call("POST", "/v1/betaTesters", {"data": {
                "type": "betaTesters",
                "attributes": {"email": e, "firstName": first.title() or "Tester",
                               "lastName": (last or "Arivu").title()},
                "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}})
            print(f"   invited {e}")
        except SystemExit:
            print(f"   {e}: already a tester, or not an App Store Connect user (internal groups "
                  f"require one)", file=sys.stderr)


def cmd_status():
    aid = app_id()
    rows = builds(aid)
    if not rows:
        print("no builds uploaded yet")
        return
    print(f"{'version':>10}  {'state':<12} {'expired':<8} uploaded")
    for b in rows:
        a = b["attributes"]
        print(f"{a.get('version',''):>10}  {a['processingState']:<12} "
              f"{str(a.get('expired', '')):<8} {a.get('uploadedDate','')}")
    print("\nVALID means testable. PROCESSING on a 1 GB app takes well over Apple's usual 15 minutes.")


def cmd_groups():
    aid = app_id()
    for g in call("GET", f"/v1/betaGroups?filter[app]={aid}&limit=200")["data"]:
        a = g["attributes"]
        kind = "internal" if a.get("isInternalGroup") else "external"
        print(f"  {a['name']:<24} {kind:<9} public-link={a.get('publicLinkEnabled')}")


def cmd_internal(name):
    aid = app_id()
    b = newest_build(aid)
    gid = ensure_group(aid, name, internal=True)
    attach_build(gid, b["id"])
    set_whats_new(b["id"])
    print("\nInternal testers must already be users on the account. Add them under\n"
          "Users and Access, then add them to this group — no review, they can install at once.")


def leaf_block(heading):
    """A fenced text block under a heading in testflight-beta.md, so copy lives in one place."""
    md = (ROOT / "leaves/gtm/testflight-beta.md").read_text()
    if heading not in md:
        die(f"no '{heading}' section in leaves/gtm/testflight-beta.md")
    return md.split(heading, 1)[1].split("```text", 1)[1].split("```", 1)[0].strip()


def cmd_prepare(contact_name, phone):
    """Everything external review needs ON THE APP, as opposed to on the build.

    A submission without these is rejected for missing metadata, which costs a day — the one thing
    a deadline cannot spare. Done separately from `external` so it can be run and checked early.
    """
    aid = app_id()
    description = leaf_block("## Beta App Description")
    feedback = leaf_block("## Feedback email")
    first, _, last = contact_name.partition(" ")

    locs = call("GET", f"/v1/apps/{aid}/betaAppLocalizations")["data"]
    body_attrs = {"description": description, "feedbackEmail": feedback}
    for loc in locs:
        if loc["attributes"]["locale"].startswith("en"):
            call("PATCH", f"/v1/betaAppLocalizations/{loc['id']}",
                 {"data": {"type": "betaAppLocalizations", "id": loc["id"],
                           "attributes": body_attrs}})
            print(f"   beta description + feedback email set ({loc['attributes']['locale']})")
            break
    else:
        call("POST", "/v1/betaAppLocalizations", {"data": {
            "type": "betaAppLocalizations",
            "attributes": {"locale": "en-US", **body_attrs},
            "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
        print("   beta description + feedback email created")

    details = call("GET", f"/v1/apps/{aid}/betaAppReviewDetail")["data"]
    call("PATCH", f"/v1/betaAppReviewDetails/{details['id']}", {"data": {
        "type": "betaAppReviewDetails", "id": details["id"],
        "attributes": {
            "contactFirstName": first, "contactLastName": last or first,
            "contactEmail": feedback, "contactPhone": phone,
            # There is no account in this app, so there is nothing to give a reviewer.
            "demoAccountRequired": False,
            "notes": leaf_block("### Notes for the reviewer")}}})
    print("   review contact and reviewer notes set")


def cmd_external(name, emails):
    aid = app_id()
    b = newest_build(aid)
    gid = ensure_group(aid, name, internal=False)
    attach_build(gid, b["id"])
    set_whats_new(b["id"])
    if emails:
        add_testers(gid, emails)
    call("POST", "/v1/betaAppReviewSubmissions", {"data": {
        "type": "betaAppReviewSubmissions",
        "relationships": {"build": {"data": {"type": "builds", "id": b["id"]}}}}})
    print("\nSubmitted for Beta App Review. Usually about a day, sometimes hours, never promised.\n"
          "Testers are invited now but cannot install until it is approved.")


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return
    cmd, rest = args[0], args[1:]
    if cmd == "status":
        cmd_status()
    elif cmd == "groups":
        cmd_groups()
    elif cmd == "internal":
        cmd_internal(rest[0] if rest else "Demo")
    elif cmd == "external":
        if not rest:
            die("usage: external <group-name> [email ...]")
        cmd_external(rest[0], rest[1:])
    elif cmd == "prepare":
        if len(rest) < 2:
            die('usage: prepare "Firstname Lastname" "+44..."')
        cmd_prepare(rest[0], rest[1])
    elif cmd == "whats-new":
        set_whats_new(newest_build(app_id())["id"])
    else:
        die(f"unknown command {cmd!r}")


if __name__ == "__main__":
    main()
