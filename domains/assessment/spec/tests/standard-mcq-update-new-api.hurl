# POST /standard-mcqs/update: the limit the new API adds (PHP has none: every unknown id would cost a result row). New API only (finding 13; a decision for the owner).
# Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh). The refusal comes before the lock, so this file may run in parallel with the others.

# 20 ids are accepted (unknown ids: failed rows, nothing read); 21 are refused
POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1], "levels": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Too many ids in levels"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Too many ids in languages"
