# GET /reports/registrations/download?format=pdf and /allocated/download?format=pdf: the PDFs of the registrations files, new API only. PHP's Dompdf runs out of its 256 MB of memory on the parity database's waiting list (a fatal error, not a PDF), so this case cannot pass there.
# Variables: base_url and auth_<alias> (B5B membership fixtures).
GET {{base_url}}/reports/registrations/download?format=pdf
Authorization: {{auth_b5b_admin}}
HTTP 200
Content-Type: application/pdf
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-Gents-[0-9]{8}\.pdf"$/
bytes startsWith hex,25504446;

# The placed-registrations file as a PDF (PHP cannot, see above)
GET {{base_url}}/reports/registrations/allocated/download?format=pdf
Authorization: {{auth_b5d_coord}}
HTTP 200
Content-Type: application/pdf
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-placed-Gents-[0-9]{8}\.pdf"$/
bytes startsWith hex,25504446;
