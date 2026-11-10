# PATCH /me contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. It changes profile.patch (900281): tools/membership-contract.sh resets it first.
# The geo rows (Switzerland with postal code 8001 and Zürich, the United Kingdom with SW1A) are loaded by the same script.
# Not here: the gender lock (no classes exist yet; NUnit proves it) and the 500s PHP answers for mobile null or a language that is not a number.

# 1. Without sign-in: 401
PATCH {{base_url}}/me
Content-Type: application/json
{"name": "Some Name"}
HTTP 401

# 2. A body that is not JSON: 422
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 3. No updatable key: 200 with the current profile, nothing validated (even the keys that are ignored)
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"email": "other@example.invalid", "roleid": 1, "bogus": [1]}
HTTP 200
[Asserts]
jsonpath "$.name" == "Synthetic Profile Patch"
jsonpath "$.roleid" == 0
jsonpath "$.email" == "profile.patch@example.invalid"
jsonpath "$.gender" == 1

# 4. Each field's refusal: 422 with PHP's exact text
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"name": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Name cannot be empty"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"city": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "City cannot be empty"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"name": "A"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Must be at least 2 characters"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"state": "01234567890123456789012345678901234567890123456789x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Must be at most 50 characters"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"name": "Tab\tName"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Contains invalid characters"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"gender": 3}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid gender value. Use 1 for Male, 2 for Female."

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"language": 4}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid language value. Use 1 for English, 2 for Urdu, 3 for Gujarati."

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"mobile": "12345"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid mobile number"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"zip": "a_b"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid ZIP code"

# 5. The first error in PHP's field order wins (name, gender, age_range, mobile, country, state, city, language, zip)
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"zip": "a_b", "language": 4, "mobile": "1", "gender": 3, "name": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Name cannot be empty"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"zip": "a_b", "language": 4, "mobile": "1", "gender": 3}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid gender value. Use 1 for Male, 2 for Female."

# 6. The place rules: digits in a state or city, a country outside the list, a postal code that looks like a phone number
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"state": "ab3"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "State cannot contain numbers"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"city": "Zurich1"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "City cannot contain numbers"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"city": "٣x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "City cannot contain numbers"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"country": "Narnia"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose your country from the list"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"zip": "0123456789"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That does not look like a postal code. Leave it empty if you do not have one."

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"zip": "a@b.c"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid ZIP code"

# 7. A valid update stores the values as sent (untrimmed) and answers with the new profile; age_range is free text, read back as a number or null
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"name": "  Ab Cd  ", "mobile": "+911234567890", "age_range": 5, "language": 2, "city": "  Bern  ", "gender": "2"}
HTTP 200
[Asserts]
jsonpath "$.name" == "  Ab Cd  "
jsonpath "$.mobile" == "+911234567890"
jsonpath "$.age_range" == 5
jsonpath "$.language" == 2
jsonpath "$.city" == "  Bern  "
jsonpath "$.gender" == 2
jsonpath "$.token" == 900281
jsonpath "$.roleid" == 0

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"age_range": "abc"}
HTTP 200
[Asserts]
jsonpath "$.age_range" == null

# 8. A float or a boolean gender is cast like PHP's (int): 1.9 is 1, true is 1; "1abc" validates and reads back as null
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"gender": 1.9}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"gender": true}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"gender": "1abc"}
HTTP 200
[Asserts]
jsonpath "$.gender" == null

# 9. A null clears a nullable column and is not validated; the empty body keys stay
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"gender": null, "age_range": null, "city": null, "zip": ""}
HTTP 200
[Asserts]
jsonpath "$.gender" == null
jsonpath "$.age_range" == null
jsonpath "$.city" == null
jsonpath "$.zip" == null

# 10. A name with entities is stored as typed and answered decoded
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"name": "O&#039;Neil &amp; Co"}
HTTP 200
[Asserts]
jsonpath "$.name" == "O'Neil & Co"

GET {{base_url}}/me
Authorization: {{auth_profile_patch}}
HTTP 200
[Asserts]
jsonpath "$.name" == "O'Neil & Co"

# 11. A new country and postal code we hold overwrite state and city, whatever was sent
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"country": "Switzerland", "zip": "8001", "city": "Typed City", "state": "Typed State"}
HTTP 200
[Asserts]
jsonpath "$.country" == "Switzerland"
jsonpath "$.zip" == "8001"
jsonpath "$.state" == "Zürich"
jsonpath "$.city" == "Zürich"

# 12. The same country and code again change nothing, so the typed city stays; another country's code we hold overwrites them again
PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"country": "Switzerland", "zip": "8001", "city": "Typed City"}
HTTP 200
[Asserts]
jsonpath "$.city" == "Typed City"
jsonpath "$.state" == "Zürich"

PATCH {{base_url}}/me
Authorization: {{auth_profile_patch}}
Content-Type: application/json
{"country": "United Kingdom", "zip": "SW1A"}
HTTP 200
[Asserts]
jsonpath "$.country" == "United Kingdom"
jsonpath "$.zip" == "SW1A"
jsonpath "$.state" == "England"
jsonpath "$.city" == "Westminster"

# 13. The member's own GET reads what the PATCH answered
GET {{base_url}}/me
Authorization: {{auth_profile_patch}}
HTTP 200
[Asserts]
jsonpath "$.country" == "United Kingdom"
jsonpath "$.zip" == "SW1A"
jsonpath "$.name" == "O'Neil & Co"
