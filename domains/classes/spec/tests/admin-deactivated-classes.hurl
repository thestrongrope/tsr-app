# GET /admin/deactivated-classes contract: the closed classes with how and when each was closed, and the deactivation log. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: 9512 (closed; one audit row: shutdown 2025-10-05 "B4 closing" by 900910 "B4 Admin Deact"), 9515 (closed, no audit row: completed_on 2025-08-01, comment
# "B4 old comment", deleted 2025-08-02 by 900910), 9516 (closed; two audit rows: shutdown "B4 first" 2025-09-01, then completed 2025-09-15 with no reason; the class comment is "B4 sixteen comment"); 9514 is active;
# audit rows 951101 to 951103; the admin 900902 (role 1).

# 1. Without sign-in: 401
GET {{base_url}}/admin/deactivated-classes
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only deactivated-classes:manage
GET {{base_url}}/admin/deactivated-classes
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/deactivated-classes
Authorization: {{auth_en_gadmin}}
HTTP 403

# 3. A class with an audit row: type, date and reason from it, the performer's name, the time with its Z
GET {{base_url}}/admin/deactivated-classes
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.deactivated[?(@.id==9512)].code" == "B4-G-12"
jsonpath "$.deactivated[?(@.id==9512)].level" == "AMMAR"
jsonpath "$.deactivated[?(@.id==9512)].gender" == 1
jsonpath "$.deactivated[?(@.id==9512)].teacher" == "B4 Member 900922"
jsonpath "$.deactivated[?(@.id==9512)].type" == "shutdown"
jsonpath "$.deactivated[?(@.id==9512)].effectiveDate" == "2025-10-05"
jsonpath "$.deactivated[?(@.id==9512)].reason" == "B4 closing"
jsonpath "$.deactivated[?(@.id==9512)].performedBy" == "B4 Admin Deact"
jsonpath "$.deactivated[?(@.id==9512)].performedAt" == "2025-10-05T12:00:00Z"

# 4. A class closed before the audit log: type and date from its own columns, the reason from its comment, the performer from who deleted it
jsonpath "$.deactivated[?(@.id==9515)].type" == "completed"
jsonpath "$.deactivated[?(@.id==9515)].effectiveDate" == "2025-08-01"
jsonpath "$.deactivated[?(@.id==9515)].reason" == "B4 old comment"
jsonpath "$.deactivated[?(@.id==9515)].performedBy" == "B4 Admin Deact"
jsonpath "$.deactivated[?(@.id==9515)].performedAt" == "2025-08-02T09:00:00Z"

# 5. Two audit rows: the latest counts; a reason missing from its details falls back to the class comment
jsonpath "$.deactivated[?(@.id==9516)].type" == "completed"
jsonpath "$.deactivated[?(@.id==9516)].effectiveDate" == "2025-09-15"
jsonpath "$.deactivated[?(@.id==9516)].reason" == "B4 sixteen comment"
jsonpath "$.deactivated[?(@.id==9516)].performedAt" == "2025-09-15T10:00:00Z"

# 6. An active class is not listed
jsonpath "$.deactivated[?(@.id==9514)]" not exists

# 7. The log has one row per deactivation (its own id), with the class code, level and gender, and no teacher
jsonpath "$.log[?(@.id==951101)].code" == "B4-G-12"
jsonpath "$.log[?(@.id==951101)].level" == "AMMAR"
jsonpath "$.log[?(@.id==951101)].gender" == 1
jsonpath "$.log[?(@.id==951101)].type" == "shutdown"
jsonpath "$.log[?(@.id==951101)].effectiveDate" == "2025-10-05"
jsonpath "$.log[?(@.id==951101)].reason" == "B4 closing"
jsonpath "$.log[?(@.id==951101)].performedBy" == "B4 Admin Deact"
jsonpath "$.log[?(@.id==951101)].performedAt" == "2025-10-05T12:00:00Z"
jsonpath "$.log[?(@.id==951101)].teacher" not exists
jsonpath "$.log[?(@.id==951102)].type" == "shutdown"
jsonpath "$.log[?(@.id==951102)].reason" == "B4 first"
jsonpath "$.log[?(@.id==951103)].type" == "completed"
jsonpath "$.log[?(@.id==951103)].reason" == null
jsonpath "$.log[?(@.id==951103)].effectiveDate" == "2025-09-15"
