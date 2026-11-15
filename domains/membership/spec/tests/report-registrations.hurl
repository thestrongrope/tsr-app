# GET /reports/registrations contract: the people waiting to be placed in a class, newest first. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5B membership fixtures (db/synthetic/membership-b5b-fixtures.sql): 901811 gents with two forms (Pending for 9561, then Accepted: the status is the greatest text, Pending),
# 901812 gents Rejected then Pending (hidden), 901813 in an active class (hidden), 901814 ladies, 901815 placeholder email (hidden), 901816 for a closed class, 901817 enrolment removed, 901818 gender Male (in neither
# list), 901819 for a class that is gone. The two databases hold different populations, so every case looks at the fixture members only.

# 1. Without sign-in: 401; without registrations:read: 403
GET {{base_url}}/reports/registrations
HTTP 401

GET {{base_url}}/reports/registrations
Authorization: {{auth_b5b_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The super administrator: gents by default
GET {{base_url}}/reports/registrations
Authorization: {{auth_b5b_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.registrants[?(@.token==901811)].id" == 951502
jsonpath "$.registrants[?(@.token==901811)].name" == "B5B Member 901811"
jsonpath "$.registrants[?(@.token==901811)].status" == "Pending"
jsonpath "$.registrants[?(@.token==901811)].registeredOn" == "2025-04-03"
jsonpath "$.registrants[?(@.token==901811)].requestedClass" == "B4B-G-61"
jsonpath "$.registrants[?(@.token==901811)].email" == "b5b.901811@example.invalid"
jsonpath "$.registrants[?(@.token==901811)].mobile" == "+910000181811"
jsonpath "$.registrants[?(@.token==901811)].residenceLocation" == "B5B Home"
jsonpath "$.registrants[?(@.token==901811)].preferredLocation" == "B5B Pune & Co"
jsonpath "$.registrants[?(@.token==901811)].birthYear" == 1991
jsonpath "$.registrants[?(@.token==901811)].classLevel" == "Primary"
jsonpath "$.registrants[?(@.token==901811)].profession" == "Engineer"
jsonpath "$.registrants[?(@.token==901811)].islamicStudyYears" == "5"
jsonpath "$.registrants[?(@.token==901811)].city" == "Pune"
jsonpath "$.registrants[?(@.token==901811)].country" == "India"
jsonpath "$.registrants[?(@.token==901811)].zip" == "411001"
jsonpath "$.registrants[?(@.token==901811)].workLocation" == null
jsonpath "$.registrants[?(@.token==901811)].interests" == null
jsonpath "$.registrants[?(@.token==901812)]" not exists
jsonpath "$.registrants[?(@.token==901813)]" not exists
jsonpath "$.registrants[?(@.token==901814)]" not exists
jsonpath "$.registrants[?(@.token==901815)]" not exists
jsonpath "$.registrants[?(@.token==901818)]" not exists

# 3. A closed class is not a requested class; a removed enrolment does not hide the member; a class that is gone; entity text is decoded; an empty mobile is null
GET {{base_url}}/reports/registrations
Authorization: {{auth_b5b_admin}}
HTTP 200
[Asserts]
jsonpath "$.registrants[?(@.token==901816)].requestedClass" == null
jsonpath "$.registrants[?(@.token==901816)].registeredOn" == "2025-05-01"
jsonpath "$.registrants[?(@.token==901817)].registeredOn" == "2025-04-02"
jsonpath "$.registrants[?(@.token==901819)].requestedClass" == null
jsonpath "$.registrants[?(@.token==901819)].mobile" == null
jsonpath "$.registrants[?(@.token==901819)].profession" == "Tom & Jerry"

# 4. Ladies for the text 2; any other text is gents
GET {{base_url}}/reports/registrations?gender=2
Authorization: {{auth_b5b_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.registrants[?(@.token==901814)].requestedClass" == "B4B-L-62"
jsonpath "$.registrants[?(@.token==901814)].birthYear" == 1985
jsonpath "$.registrants[?(@.token==901814)].islamicStudyYears" == "2"
jsonpath "$.registrants[?(@.token==901811)]" not exists
jsonpath "$.registrants[?(@.token==901818)]" not exists

GET {{base_url}}/reports/registrations?gender=abc
Authorization: {{auth_b5b_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

# 5. A gender administrator keeps their gender whatever they ask for
GET {{base_url}}/reports/registrations?gender=2
Authorization: {{auth_b5b_gents_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.registrants[?(@.token==901811)]" exists
jsonpath "$.registrants[?(@.token==901814)]" not exists

GET {{base_url}}/reports/registrations?gender=1
Authorization: {{auth_b5b_ladies_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.registrants[?(@.token==901814)]" exists
jsonpath "$.registrants[?(@.token==901811)]" not exists

# 6. A coordinator assigned one gents class (b5d_coord: 9561 only) is locked to gents and sees every waiting person of that gender: the one who asked for the assigned class, the ones who asked for another class
# (closed, gone) and the open request; never a lady
GET {{base_url}}/reports/registrations?gender=2
Authorization: {{auth_b5d_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.registrants[?(@.token==901811)].requestedClass" == "B4B-G-61"
jsonpath "$.registrants[?(@.token==901816)]" exists
jsonpath "$.registrants[?(@.token==901817)]" exists
jsonpath "$.registrants[?(@.token==901819)]" exists
jsonpath "$.registrants[?(@.token==901814)]" not exists
jsonpath "$.registrants[?(@.token==901812)]" not exists
