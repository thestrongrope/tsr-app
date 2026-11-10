# POST /registration contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. It changes rows: tools/membership-contract.sh resets them first.

# 1. Without sign-in: 401
POST {{base_url}}/registration
Content-Type: application/json
{"preferredLocation": "x", "birthYear": 1990, "islamicStudyYears": 1}
HTTP 401

# 2. A required field missing, blank, or islamicStudyYears empty: 422 with PHP's message
POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
{"birthYear": 1990, "islamicStudyYears": 1}
HTTP 422
[Asserts]
jsonpath "$.detail" == "preferredLocation, birthYear and islamicStudyYears are required"

POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
{"preferredLocation": "  ", "birthYear": 1990, "islamicStudyYears": 1}
HTTP 422
[Asserts]
jsonpath "$.detail" == "preferredLocation, birthYear and islamicStudyYears are required"

POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
{"preferredLocation": "Zurich", "birthYear": 1990, "islamicStudyYears": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "preferredLocation, birthYear and islamicStudyYears are required"

# 3. A body that is not JSON: 422 Invalid JSON body (before the required fields are looked at)
POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 4. A first save: 200, and the form reads back whitelisted and trimmed (an unknown dropdown value is dropped, not refused)
POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
{
  "preferredLocation": "  Zurich  ",
  "birthYear": "1990",
  "islamicStudyYears": "0",
  "linkedinUrl": "https://www.linkedin.com/in/some-person",
  "residenceLocation": "Basel",
  "workLocation": "   ",
  "education": "Doctorate (PhD / DPhil)",
  "fieldOfStudy": ["Law", "Nope", " Science "],
  "professionalCourses": "not a list",
  "occupationType": "not a label",
  "fieldOfWork": "Education / Training",
  "yearsExperience": "3-5 years",
  "otherInterests": "Calligraphy",
  "languages": {"English": {"Read": "Fluent", "Write": "Don't Know"}, "Klingon": {"Read": "Fluent"}},
  "interestIds": [11, 999, 13]
}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.message" == "Class request submitted successfully"

GET {{base_url}}/registration
Authorization: {{auth_fresh}}
HTTP 200
[Asserts]
jsonpath "$.registration.preferredLocation" == "Zurich"
jsonpath "$.registration.birthYear" == 1990
jsonpath "$.registration.islamicStudyYears" == 0
jsonpath "$.registration.linkedinUrl" == "https://www.linkedin.com/in/some-person"
jsonpath "$.registration.residenceLocation" == "Basel"
jsonpath "$.registration.workLocation" == null
jsonpath "$.registration.education" == "Doctorate (PhD / DPhil)"
jsonpath "$.registration.fieldOfStudy" count == 2
jsonpath "$.registration.fieldOfStudy[0]" == "Law"
jsonpath "$.registration.fieldOfStudy[1]" == "Science"
jsonpath "$.registration.professionalCourses" count == 0
jsonpath "$.registration.occupationType" == null
jsonpath "$.registration.fieldOfWork" == "Education / Training"
jsonpath "$.registration.yearsExperience" == "3-5 years"
jsonpath "$.registration.otherInterests" == "Calligraphy"
jsonpath "$.registration.status" == "Pending"
jsonpath "$.selectedInterestIds" count == 2
jsonpath "$.selectedInterestIds" contains 11
jsonpath "$.selectedInterestIds" contains 13
body contains "\"languages\":{\"English\":{\"Read\":\"Fluent\"}}"
jsonpath "$.languages.English.Read" == "Fluent"

# 5. A second save updates the row (no duplicate): the form is replaced, the status stays, an empty languages map keeps the saved ones,
#    a missing interestIds keeps the choices, a bad LinkedIn address and a text number are cast or dropped, not refused
POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
{"preferredLocation": "Basel", "birthYear": "abc", "islamicStudyYears": 3, "linkedinUrl": "https://example.com/in/x", "languages": {}}
HTTP 200

GET {{base_url}}/registration
Authorization: {{auth_fresh}}
HTTP 200
[Asserts]
jsonpath "$.registration.preferredLocation" == "Basel"
jsonpath "$.registration.birthYear" == 0
jsonpath "$.registration.islamicStudyYears" == 3
jsonpath "$.registration.linkedinUrl" == null
jsonpath "$.registration.education" == null
jsonpath "$.registration.fieldOfStudy" count == 0
jsonpath "$.registration.status" == "Pending"
jsonpath "$.selectedInterestIds" count == 2
body contains "\"languages\":{\"English\":{\"Read\":\"Fluent\"}}"
jsonpath "$.languages.English.Read" == "Fluent"

# 6. A non-empty languages map of only invalid entries erases the saved ones; an empty interest list erases the choices
POST {{base_url}}/registration
Authorization: {{auth_fresh}}
Content-Type: application/json
{"preferredLocation": "Basel", "birthYear": 1990, "islamicStudyYears": 3, "languages": {"Klingon": {"Read": "Fluent"}}, "interestIds": []}
HTTP 200

GET {{base_url}}/registration
Authorization: {{auth_fresh}}
HTTP 200
[Asserts]
body contains "\"languages\":{}"
jsonpath "$.selectedInterestIds" count == 0

# 7. A member with two rows (registrant.update, a copy of registrant.duplicates that no other file uses, because Hurl runs files in
#    parallel): the update reaches every row, keeps each status, and the first row still reads back
POST {{base_url}}/registration
Authorization: {{auth_registrant_update}}
Content-Type: application/json
{"preferredLocation": "Geneva", "birthYear": 1980, "islamicStudyYears": 2}
HTTP 200

GET {{base_url}}/registration
Authorization: {{auth_registrant_update}}
HTTP 200
[Asserts]
jsonpath "$.registration.preferredLocation" == "Geneva"
jsonpath "$.registration.birthYear" == 1980
jsonpath "$.registration.status" == "Pending"
jsonpath "$.registration.otherInterests" == null
jsonpath "$.registration.linkedinUrl" == null
jsonpath "$.registration.education" == null
jsonpath "$.languages.English.Read" == "Fluent"
jsonpath "$.selectedInterestIds" count == 2
