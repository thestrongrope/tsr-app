# GET /admin/donors/download?format=pdf: the PDF of the donors list, new API only. PHP's Dompdf runs out of its 256 MB of memory on the parity database's donors (a fatal error, not a PDF), so this case cannot pass there.
# Variables: base_url and auth_<alias> (B4B fixtures).
GET {{base_url}}/admin/donors/download?format=pdf
Authorization: {{auth_b4b_donor_admin}}
HTTP 200
Content-Type: application/pdf
[Asserts]
header "Content-Disposition" matches /^attachment; filename="TSR_Donors_Export_[0-9]{8}_[0-9]{6}\.pdf"$/
bytes startsWith hex,25504446;
