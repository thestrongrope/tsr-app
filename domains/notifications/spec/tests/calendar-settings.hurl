# PUT /me/calendar/settings: a phone syncs the member's alert settings; the answer is what is now stored for each item. Runs against any implementation.
# WRITES the settings of member 928022 only (no other file signs in as them); tools/contract-calendar.sh deletes them before each run.
# Variables: base_url and auth_cal_<alias>. Fixtures: db/synthetic/calendar-fixtures.sql. 928022 (syncer) is a student of class 9706: events 9280461, 9280463, 9280464 (live), 9280462 (deleted);
# slot 9280206. 9280421 is an event of class 9702 and 9280491 one of the closed class 9709: this member is in neither. Two phones: device keys calsyncdevice-aaa and calsyncdevice-bbb.

# 422s in order: the body, the device key, the batch, a change's shape, its key
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"changes": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "device_key must be a random installation identifier (16-64 characters)"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "short", "changes": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "device_key must be a random installation identifier (16-64 characters)"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A batch must contain at most 200 changes"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": {"event_key": "event:9280461"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A batch must contain at most 200 changes"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [7]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each change must be an object"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": 7}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "event_key must be a string"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "quiz:1"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid event_key"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid event_key"

# 422s of a change for an item the member can see, in order: the offset, the two switches, the client time
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "offset_minutes": -7, "muted": 1}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a supported alert offset"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "offset_minutes": "-5", "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a supported alert offset"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "muted": 1, "deleted": false}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "muted and deleted must be booleans"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "muted": true}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "muted and deleted must be booleans"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "muted": true, "deleted": false}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "client_updated_at must be an ISO UTC timestamp"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00+00:00"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "client_updated_at must be an ISO UTC timestamp"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "muted": true, "deleted": false, "client_updated_at": "2026-02-30T08:00:00Z"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid client_updated_at"

# One bad change refuses the whole batch: the good change before it is not kept
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "slot:9280206", "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}, {"event_key": "slot:9280206", "muted": "no", "deleted": false}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "muted and deleted must be booleans"

GET {{base_url}}/me/calendar
Authorization: {{auth_cal_syncer}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].class_id" == 9706
jsonpath "$.classes[0].events" count == 3
jsonpath "$.classes[0].slots" count == 1
body contains "\"settings\":{}"

# 200: an empty batch
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": []}
HTTP 200
[Asserts]
body contains "\"settings\":{}"
jsonpath "$.rejected" count == 0
jsonpath "$.clock_skew" == false
jsonpath "$.server_time" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/

# 200: the first setting of an event is stored and answered
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "event:9280461", "offset_minutes": -30, "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00.5Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280461'].offset_minutes" == -30
jsonpath "$.settings['event:9280461'].muted" == true
jsonpath "$.settings['event:9280461'].deleted" == false
jsonpath "$.settings['event:9280461'].updated_at" == "2026-11-01T08:00:00.500Z"
jsonpath "$.settings['event:9280461'].server_updated_at" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.settings['event:9280461'].device_key" == "calsyncdevice-aaa"
jsonpath "$.rejected" count == 0
jsonpath "$.clock_skew" == false

# 200: items the member cannot see are rejected by key, unchecked (their bad offset is no 422), and the rest of the batch is kept
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "event:9280462", "offset_minutes": -7, "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}, {"event_key": "event:9280421", "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}, {"event_key": "event:9280491", "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}, {"event_key": "slot:99999999", "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}, {"event_key": "slot:9280206", "offset_minutes": 0, "muted": false, "deleted": false, "client_updated_at": "2026-11-01T08:00:00Z"}]}
HTTP 200
[Asserts]
jsonpath "$.rejected" count == 4
jsonpath "$.rejected[0]" == "event:9280462"
jsonpath "$.rejected[1]" == "event:9280421"
jsonpath "$.rejected[2]" == "event:9280491"
jsonpath "$.rejected[3]" == "slot:99999999"
jsonpath "$.settings['slot:9280206'].offset_minutes" == 0
jsonpath "$.settings['slot:9280206'].updated_at" == "2026-11-01T08:00:00.000Z"
jsonpath "$.settings['event:9280462']" not exists

# 200: an older change from another phone loses; the stored setting is answered
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-bbb", "changes": [{"event_key": "event:9280461", "offset_minutes": -5, "muted": false, "deleted": false, "client_updated_at": "2026-11-01T08:00:00.499Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280461'].offset_minutes" == -30
jsonpath "$.settings['event:9280461'].muted" == true
jsonpath "$.settings['event:9280461'].updated_at" == "2026-11-01T08:00:00.500Z"
jsonpath "$.settings['event:9280461'].device_key" == "calsyncdevice-aaa"

# 200: at the same millisecond the greater device key wins, and the smaller one then loses
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-bbb", "changes": [{"event_key": "event:9280461", "offset_minutes": -5, "muted": false, "deleted": false, "client_updated_at": "2026-11-01T08:00:00.500Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280461'].offset_minutes" == -5
jsonpath "$.settings['event:9280461'].muted" == false
jsonpath "$.settings['event:9280461'].device_key" == "calsyncdevice-bbb"

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "event:9280461", "offset_minutes": -60, "muted": true, "deleted": false, "client_updated_at": "2026-11-01T08:00:00.500Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280461'].offset_minutes" == -5
jsonpath "$.settings['event:9280461'].device_key" == "calsyncdevice-bbb"

# 200: a newer change wins; no offset means the app's default (null)
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "event:9280461", "muted": true, "deleted": false, "client_updated_at": "2026-11-02T00:00:00Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280461'].offset_minutes" == null
jsonpath "$.settings['event:9280461'].muted" == true
jsonpath "$.settings['event:9280461'].updated_at" == "2026-11-02T00:00:00.000Z"
jsonpath "$.settings['event:9280461'].device_key" == "calsyncdevice-aaa"

# 200: deleted is a tombstone: a later change that says deleted false does not bring the item back
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "event:9280463", "muted": false, "deleted": true, "client_updated_at": "2026-11-01T08:00:00Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280463'].deleted" == true

PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-bbb", "changes": [{"event_key": "event:9280463", "muted": true, "deleted": false, "client_updated_at": "2026-11-03T08:00:00Z"}]}
HTTP 200
[Asserts]
jsonpath "$.settings['event:9280463'].deleted" == true
jsonpath "$.settings['event:9280463'].muted" == true
jsonpath "$.settings['event:9280463'].updated_at" == "2026-11-03T08:00:00.000Z"

# 200: a phone whose clock runs far ahead is given the server's time and told
PUT {{base_url}}/me/calendar/settings
Authorization: {{auth_cal_syncer}}
{"device_key": "calsyncdevice-aaa", "changes": [{"event_key": "event:9280464", "offset_minutes": -1440, "muted": false, "deleted": false, "client_updated_at": "2099-01-01T00:00:00Z"}]}
HTTP 200
[Asserts]
jsonpath "$.clock_skew" == true
jsonpath "$.settings['event:9280464'].offset_minutes" == -1440
jsonpath "$.settings['event:9280464'].updated_at" != "2099-01-01T00:00:00.000Z"
jsonpath "$.settings['event:9280464'].updated_at" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/

# The calendar now hides the tombstoned event and answers every stored setting
GET {{base_url}}/me/calendar
Authorization: {{auth_cal_syncer}}
HTTP 200
[Asserts]
jsonpath "$.classes[0].events" count == 2
jsonpath "$.classes[0].events[0].id" == 9280461
jsonpath "$.classes[0].events[1].id" == 9280464
jsonpath "$.classes[0].slots" count == 1
jsonpath "$.settings['event:9280461'].muted" == true
jsonpath "$.settings['event:9280463'].deleted" == true
jsonpath "$.settings['event:9280464'].offset_minutes" == -1440
jsonpath "$.settings['slot:9280206'].offset_minutes" == 0
jsonpath "$.settings['event:9280462']" not exists
