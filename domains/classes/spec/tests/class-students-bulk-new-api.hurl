# POST /classes/{class_id}/students/bulk, cases PHP gets wrong (new API only). BULK fixtures: see class-students-bulk.hurl.
# A NUL byte in a line: PHP's database takes it, PostgreSQL cannot store it, so it is a 422 here (bk_adm_f: 1 call).
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_f}}
{"lines": ["Nul\u0000Name"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each line must be text of at most 300 characters"
