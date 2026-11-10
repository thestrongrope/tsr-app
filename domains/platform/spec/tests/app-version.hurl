# GET /app-version contract: public, fail-open, read from the synthetic catalog.
# The catalog is app_versions.synthetic.json in this folder: the dev stack and the PHP parity stack both
# mount that one file (docker-compose.dev.yml, tools/parity-php/compose.parity.yml), so a run on either
# side must give these answers. The bad-file cases (missing, corrupt, 12.0 and so on) cannot be reached
# over HTTP; they are unit tests (domains/platform/api/domain/AppCatalog.Tests.cs).
# Variable: base_url. No sign-in is used or needed.

# 1. No sign-in needed; the payload is an object with android, ios and announcement, in that order
GET {{base_url}}/app-version
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.android.minimumBuild" == 50
jsonpath "$.android.recommendedBuild" == 52
jsonpath "$.android.storeUrl" == "https://example.invalid/android"
# the release whose android build equals recommendedBuild gives the notes; empty notes are dropped, so is the number 7
jsonpath "$.android.latest.version" == "9.2.0"
jsonpath "$.android.latest.notes[0]" == "Second note"
jsonpath "$.android.latest.notes[1]" == "Third note"
jsonpath "$.android.latest.notes" count == 2
body matches /^\{"android":\{.*\},"ios":\{.*\},"announcement":\{.*\}\}$/

# 2. A quoted minimumBuild ("12") is not an integer: the whole ios block is the fallback, with no latest
GET {{base_url}}/app-version
HTTP 200
[Asserts]
jsonpath "$.ios.minimumBuild" == 1
jsonpath "$.ios.recommendedBuild" == 1
jsonpath "$.ios.storeUrl" == "https://apps.apple.com/app/id6807232453"
jsonpath "$.ios.latest" not exists
jsonpath "$.android.minimumBuild" == 50

# 3. An announcement body that is not a string is an empty string
GET {{base_url}}/app-version
HTTP 200
[Asserts]
jsonpath "$.announcement.id" == "synthetic-1"
jsonpath "$.announcement.title" == "A synthetic announcement"
jsonpath "$.announcement.body" == ""

# 4. A bad bearer token does not matter: the route never reads it
GET {{base_url}}/app-version
Authorization: Bearer not-a-real-token
HTTP 200
[Asserts]
jsonpath "$.android.minimumBuild" == 50
