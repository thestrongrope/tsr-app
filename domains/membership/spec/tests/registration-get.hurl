# GET /registration contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias> (one Bearer value per fixture member). Synthetic members only.
# Do not run it by hand: tools/membership-contract.sh dev|parity resets the fixtures, signs the members in and runs every file
# (tools/membership-contract.sh dev --prepare does the first two for the all-files command in CLAUDE.md).

# 1. Without sign-in: 401 with a detail
GET {{base_url}}/registration
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member with duplicate rows: the first (Pending) row, raw values, the option list, their choices and languages
GET {{base_url}}/registration
Authorization: {{auth_registrant_dup}}
HTTP 200
[Asserts]
jsonpath "$.registration.preferredLocation" == "Zurich, Online"
jsonpath "$.registration.birthYear" == 1990
jsonpath "$.registration.islamicStudyYears" == 5
jsonpath "$.registration.linkedinUrl" == "https://www.linkedin.com/in/synthetic-person"
jsonpath "$.registration.residenceLocation" == "Zurich"
jsonpath "$.registration.workLocation" == "Basel"
jsonpath "$.registration.education" == "Graduate (Bachelor's Degree)"
jsonpath "$.registration.fieldOfStudy" count == 2
jsonpath "$.registration.fieldOfStudy[0]" == "Law"
jsonpath "$.registration.fieldOfStudy[1]" == "Science"
jsonpath "$.registration.fieldOfStudyOther" == null
jsonpath "$.registration.professionalCourses" count == 0
jsonpath "$.registration.professionalCoursesOther" == null
jsonpath "$.registration.occupationType" == "Salaried Professional"
jsonpath "$.registration.fieldOfWork" == null
jsonpath "$.registration.yearsExperience" == "3-5 years"
jsonpath "$.registration.roleLevel" == null
jsonpath "$.registration.otherInterests" == "Calligraphy"
jsonpath "$.registration.status" == "Pending"
jsonpath "$.registration.statusReason" not exists
jsonpath "$.interestOptions" count == 16
jsonpath "$.interestOptions" count == 16
jsonpath "$.interestOptions[0].id" == 11
jsonpath "$.interestOptions[1].id" == 13
jsonpath "$.interestOptions[2].id" == 1
jsonpath "$.interestOptions[3].id" == 14
jsonpath "$.interestOptions[4].id" == 15
jsonpath "$.interestOptions[5].id" == 2
jsonpath "$.interestOptions[6].id" == 16
jsonpath "$.interestOptions[7].id" == 5
jsonpath "$.interestOptions[8].id" == 6
jsonpath "$.interestOptions[9].id" == 8
jsonpath "$.interestOptions[10].id" == 9
jsonpath "$.interestOptions[11].id" == 17
jsonpath "$.interestOptions[12].id" == 10
jsonpath "$.interestOptions[13].id" == 18
jsonpath "$.interestOptions[14].id" == 19
jsonpath "$.interestOptions[15].id" == 7
jsonpath "$.interestOptions[0].name" == "Teaching"
jsonpath "$.interestOptions[15].name" == "Other"
jsonpath "$.selectedInterestIds" count == 2
jsonpath "$.selectedInterestIds" contains 11
jsonpath "$.selectedInterestIds" contains 13
jsonpath "$.languages.English.Read" == "Fluent"
jsonpath "$.languages.English.Speak" == "Fluent"
jsonpath "$.languages.Urdu.Read" == "Learning"
jsonpath "$.languages.Arabic.Understand" == "Beginner"

# 3. A member with one Accepted row and an empty multi-select, no languages: an empty object, not an empty list
GET {{base_url}}/registration
Authorization: {{auth_registrant_one}}
HTTP 200
[Asserts]
jsonpath "$.registration.status" == "Accepted"
jsonpath "$.registration.islamicStudyYears" == 0
jsonpath "$.registration.fieldOfStudy" count == 0
jsonpath "$.registration.education" == "Not Applicable / Prefer not to say"
jsonpath "$.selectedInterestIds" count == 1
jsonpath "$.selectedInterestIds[0]" == 9
body contains "\"languages\":{}"
body contains "\"languages\":{}"

# 4. A member with nothing saved: a null registration, empty choices
GET {{base_url}}/registration
Authorization: {{auth_gender_null}}
HTTP 200
[Asserts]
jsonpath "$.registration" == null
jsonpath "$.interestOptions" count == 16
jsonpath "$.selectedInterestIds" count == 0
body contains "\"languages\":{}"
