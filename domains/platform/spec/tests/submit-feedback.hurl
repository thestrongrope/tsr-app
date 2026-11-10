# POST /feedback contract: 8 cases, one file per slice.
# Runs against any implementation. Variables: base_url, auth_header, auth_value
# (a token is never written into this file). Synthetic members only.
# New API:
#   hurl --test --variable base_url=http://localhost:8088 \
#        --variable auth_header=X-Dev-Token --variable auth_value=900001 submit-feedback.hurl
# PHP parity stack (tools/parity-php/README.md): mint-token.sh writes the two auth
# variables to build/parity-php/token.vars, so:
#   hurl --test --variable base_url=http://127.0.0.1:18091 \
#        --variables-file build/parity-php/token.vars submit-feedback.hurl
# Every contract file at once: see CLAUDE.md, Commands.

# 1. Without sign-in: 401 with a detail
POST {{base_url}}/feedback
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member sends feedback: 201 with an id
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "{{newUuid}}", "text": "JazakAllah for the app"}
HTTP 201
[Asserts]
jsonpath "$.id" isInteger
jsonpath "$.id" >= 1

# 3. A replay with the same clientId returns the same id
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
[Options]
variable: replay_id={{newUuid}}
{"clientId": "{{replay_id}}", "text": "sent twice because the reply was lost"}
HTTP 201
[Captures]
first_id: jsonpath "$.id"

POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "{{replay_id}}", "text": "sent twice because the reply was lost"}
HTTP 201
[Asserts]
jsonpath "$.id" == {{first_id}}

# 8. A replay with the clientId in upper case returns the same id.
# Hurl has no upper-case filter, so the id is fixed: a rerun is itself a replay, which still holds.
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "text": "case does not make a new message"}
HTTP 201
[Captures]
lower_id: jsonpath "$.id"

POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D", "text": "case does not make a new message"}
HTTP 201
[Asserts]
jsonpath "$.id" == {{lower_id}}

# 4. Empty text is 422 with a detail
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "{{newUuid}}", "text": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

# 5. Whitespace-only text is 422 with a detail
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "{{newUuid}}", "text": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

# 6. Text over 2000 characters is 422
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"clientId": "{{newUuid}}", "text": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422

# 7. A missing clientId is 422 with a detail
POST {{base_url}}/feedback
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"text": "no id"}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/
