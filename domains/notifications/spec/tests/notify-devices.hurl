# POST /devices and DELETE /devices contract: a member's own push addresses. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. 926011 (dev) registers and removes its own devices; 926012 (displacer) registers a device that 926013 (victim) holds (n6-held-1).
# Findings 9 and 17 of build-out-findings.md: in PHP the device id IS the FCM token (one column), so registering a push token and registering a device id are the same act. A device belongs to whoever registered it LAST:
# knowing the token is the only credential, and the previous holder's row is deleted (PHP's #428). That is the contract here and a proposal for the owner (test-notify-notes.md), not something this file hides.

# 1. Without sign-in: 401, both verbs
POST {{base_url}}/devices
{"fcmToken": "n6-fresh-1"}
HTTP 401

DELETE {{base_url}}/devices
{"fcmToken": "n6-fresh-1"}
HTTP 401

# 2. Register: 201 {ok}; either spelling of the key; again is the same row (no second row, so one delete finds one)
POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "n6-dev-1"}
HTTP 201
[Asserts]
jsonpath "$.ok" == true

POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcm_token": "n6-dev-1"}
HTTP 201

# The token is trimmed
POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "  n6-dev-2  "}
HTTP 201

# 3. Validation: 422 with PHP's wording
POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "fcmToken is required"

POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "fcmToken is required"

POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "fcmToken is required"

POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": ["n6-dev-1"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "fcmToken is required"

POST {{base_url}}/devices
Authorization: {{auth_nf_dev}}
```
not json
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 4. Remove: one row (the trimmed one is stored trimmed); again 0; another spelling of the same token finds nothing here but the same row (the column is case-insensitive in both)
DELETE {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "n6-dev-2"}
HTTP 200
[Asserts]
jsonpath "$.ok" == true
jsonpath "$.deleted" == 1

DELETE {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "n6-dev-2"}
HTTP 200
[Asserts]
jsonpath "$.deleted" == 0

DELETE {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "N6-DEV-1"}
HTTP 200
[Asserts]
jsonpath "$.deleted" == 1

DELETE {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "fcmToken is required"

# 5. Own rows only: 926011 cannot remove a device another member holds (n6-held-1 is 926013's): 0 rows, 200
DELETE {{base_url}}/devices
Authorization: {{auth_nf_dev}}
{"fcmToken": "n6-held-1"}
HTTP 200
[Asserts]
jsonpath "$.deleted" == 0

# 6. Findings 9 and 17: the displacer registers the token the victim holds, spelt in other case. The victim's row is gone (a delete by the victim finds 0), the displacer's is there (a delete finds 1)
POST {{base_url}}/devices
Authorization: {{auth_nf_displacer}}
{"fcmToken": "N6-HELD-1"}
HTTP 201

DELETE {{base_url}}/devices
Authorization: {{auth_nf_victim}}
{"fcmToken": "n6-held-1"}
HTTP 200
[Asserts]
jsonpath "$.deleted" == 0

DELETE {{base_url}}/devices
Authorization: {{auth_nf_displacer}}
{"fcmToken": "n6-held-1"}
HTTP 200
[Asserts]
jsonpath "$.deleted" == 1
