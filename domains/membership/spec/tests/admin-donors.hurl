# GET /admin/donors contract: every member in an active class (one row per enrolment, no reach limit), by name. Variables: base_url and auth_<alias>.
# Fixtures: 901181 in two live classes, 901182 only in a closed class, 901183 removed from a live class, 901184 with an HTML-escaped name, no city and an empty mobile. Other files enrol people too: rows are found by e-mail, never counted.

# 1. Without sign-in: 401
GET {{base_url}}/admin/donors
HTTP 401

# 2. A member without donors:read: 403
GET {{base_url}}/admin/donors
Authorization: {{auth_b4b_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The list: a member in two live classes shows twice, a closed class or a removal shows no row
GET {{base_url}}/admin/donors
Authorization: {{auth_b4b_donor_admin}}
HTTP 200
[Asserts]
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')]" count == 2
jsonpath "$.donors[?(@.email == 'b4b.901182@example.invalid')]" not exists
jsonpath "$.donors[?(@.email == 'b4b.901183@example.invalid')]" not exists
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')].name" nth 0 == "B4B Member 901181"
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')].city" nth 0 == "Pune"
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')].state" nth 0 == "MH"
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')].country" nth 0 == "India"
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')].zip" nth 0 == "411001"
jsonpath "$.donors[?(@.email == 'b4b.901181@example.invalid')].mobile" nth 0 == "+910000111181"

# 4. Text is entity-decoded and an empty or missing value is null
GET {{base_url}}/admin/donors
Authorization: {{auth_b4b_donor_admin}}
HTTP 200
[Asserts]
jsonpath "$.donors[?(@.email == 'b4b.901184@example.invalid')].name" == "O'Brien & Donor"
jsonpath "$.donors[?(@.email == 'b4b.901184@example.invalid' && @.city == null && @.mobile == null)].email" == "b4b.901184@example.invalid"
