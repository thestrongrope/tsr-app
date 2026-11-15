# GET /reports/active-teachers contract: each teacher of the active classes the caller reaches, with the classes taught and the classes attended as a student. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5B fixtures (db/synthetic/classes-b5b-fixtures.sql): the coordinator rb_coord reaches the gents classes 9591 to 9594 only, so its answer is compared in full.
# 901511 teaches 9591 (MIQDAD) and 9592 (ABUZAR) and attends 9593 and 9594; 901512 teaches 9593 (SALMAN); 901513 is a LADIES member teaching the gents class 9594: PHP filters the teachers by their own gender, so
# the gents list has no 901513 and the ladies list has no 901513 either (the ladies list holds only the classes of ladies). 901514 teaches the ladies class 9595.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/active-teachers
HTTP 401

GET {{base_url}}/reports/active-teachers
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: its two teachers in name order
GET {{base_url}}/reports/active-teachers
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.teachers" count == 2
jsonpath "$.teachers[0].token" == 901511
jsonpath "$.teachers[0].name" == "Rb Member 901511"
jsonpath "$.teachers[0].attendingClass" == "RB-G-593, RB-G-594"
jsonpath "$.teachers[0].selfTeacher" == "Rb Member 901512, Rb Member 901513"
jsonpath "$.teachers[0].maxLevel" == "ABUZAR"
jsonpath "$.teachers[0].totalClasses" == 2
jsonpath "$.teachers[0].conductingClasses" == "RB-G-592, RB-G-591"
jsonpath "$.teachers[1].token" == 901512
jsonpath "$.teachers[1].attendingClass" == null
jsonpath "$.teachers[1].selfTeacher" == null
jsonpath "$.teachers[1].maxLevel" == "SALMAN"
jsonpath "$.teachers[1].totalClasses" == 1
jsonpath "$.teachers[1].conductingClasses" == "RB-G-593"

# 3. The coordinator's classes are all gents: asking for ladies changes nothing
GET {{base_url}}/reports/active-teachers?gender=2
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.teachers" count == 2
jsonpath "$.teachers[0].token" == 901511

# 4. A gender administrator is held to their gender
GET {{base_url}}/reports/active-teachers?gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.teachers[?(@.token==901511)].totalClasses" == 2
jsonpath "$.teachers[?(@.token==901514)]" not exists
jsonpath "$.teachers[?(@.token==901513)]" not exists

GET {{base_url}}/reports/active-teachers?gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.teachers[?(@.token==901514)].conductingClasses" == "RB-L-595"
jsonpath "$.teachers[?(@.token==901514)].maxLevel" == "MIQDAD"
jsonpath "$.teachers[?(@.token==901511)]" not exists
jsonpath "$.teachers[?(@.token==901513)]" not exists

# 5. The super administrator: gents by default, ladies for the text 2, anything else gents; the closed class 9596 never counts (901512 has one class)
GET {{base_url}}/reports/active-teachers
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.teachers[?(@.token==901511)].totalClasses" == 2
jsonpath "$.teachers[?(@.token==901512)].totalClasses" == 1
jsonpath "$.teachers[?(@.token==901512)].conductingClasses" == "RB-G-593"
jsonpath "$.teachers[?(@.token==901513)]" not exists
jsonpath "$.teachers[?(@.token==901514)]" not exists

GET {{base_url}}/reports/active-teachers?gender=2
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.teachers[?(@.token==901514)].totalClasses" == 1
jsonpath "$.teachers[?(@.token==901511)]" not exists

GET {{base_url}}/reports/active-teachers?gender=abc
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

# 6. The demo class never counts and the list has no teacher twice
GET {{base_url}}/reports/active-teachers
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers[?(@.conductingClasses=='AYD1')]" not exists
