# Re-link and log out with no notifier: each attempt is 502 with the route's own words, and the shared limit is 6 a minute per member (429 on the 7th). Cache-Control: no-store throughout.
# NEW API ONLY: PHP's two routes die with "Call to undefined function api_log_admin_action()" (lib/audit.php is not loaded by that routes file; a PHP bug, see docs/specs/initial-build/test-edge-notes.md).
# The admin audit row each attempt writes is proved in db/tests/TestEdgeWhatsappTests.cs. Do not run twice within a minute: the limit is per member and per minute.
# Variables: base_url, auth_edge_wa_change (super admin, used by this file only).

POST {{base_url}}/admin/whatsapp/link/relink
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 502
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "Re-link failed. The link is unchanged; please try again."

POST {{base_url}}/admin/whatsapp/link/logout
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 502
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "Logout failed. The link is unchanged; please try again."

POST {{base_url}}/admin/whatsapp/link/relink
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 502

POST {{base_url}}/admin/whatsapp/link/logout
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 502

POST {{base_url}}/admin/whatsapp/link/relink
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 502

POST {{base_url}}/admin/whatsapp/link/logout
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 502

# The 7th call in the minute, of either kind
POST {{base_url}}/admin/whatsapp/link/relink
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 429
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "Too many requests. Please wait a minute and try again."

POST {{base_url}}/admin/whatsapp/link/logout
Authorization: {{auth_edge_wa_change}}
Content-Type: application/json
{}
HTTP 429
[Asserts]
header "Cache-Control" == "no-store"
