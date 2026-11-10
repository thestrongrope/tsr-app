# membership: glossary

Use these words in code, tests, screens and messages. If a word is missing, add it here first.

| Term | Meaning | In code |
|---|---|---|
| **Member** | A signed-in person. identity knows who they are (id, token, email); membership knows their profile. | `Caller`; `identity.users` |
| **Token** | The member's number the whole system keys on (PHP's `users.token`). Not unique: every guest has 0 and a few members share one. | `Caller.Token`; `*_token` columns |
| **Profile** | What a member says about themselves: name, gender, age range, mobile, country, state, city, language, postal code, picture. One row per member, created on the first write. | table `member_profiles`; `MemberProfile` |
| **Gender** | PHP's raw text: '1' (male), '2' (female), 'Male', 'Female', empty or null. Kept as it is so every PHP reading of it stays the same. | `MemberProfile.Gender` |
| **Gender lock** | A member in a class may not change gender, so they cannot switch, join the other gender's class and switch back. | `GenderLock`; port `IClassEnrolments` |
| **Place** | A member's country, state, city and postal code. A new postal code we hold replaces state and city. | `PlaceCheck`, `PlaceRules` |
| **Class request** | The form a member fills in to ask for classes: where they live and work, birth year, study years, education, field, courses, occupation, LinkedIn, languages, interests. Also called a registration. | `class_registrations`; `GET` and `POST /registration` |
| **Registration status** | Pending, Accepted or Rejected. The form never changes it. | `ClassRegistration.Status` |
| **Language skill** | One line of the form: a language, a skill (Read, Speak, Understand, Write) and how well (Beginner, Learning, Fluent). "Don't Know" is not saved. | `class_registrations_languages` |
| **Interest** | One thing a member could help with (Teaching, Research...). The options are a table; a member's choices are another. | `interest_options`, `student_interests` |
| **Guardian link** | A parent's link to a child, by token. Status invited (an invite nobody accepted), active or revoked. | table `user_guardians`; `UserGuardian` |
| **Parent, child** | The two sides of a guardian link. A child is a member who may be a young person with their own account. | `parent_token`, `child_token` |
| **Invite (link)** | A one-time code for a parent to join a child. 32 hex characters, valid for 7 days, accepted once. | `code`, `expires_at` |
| **Inspect** | Look at an invite before accepting: valid (with the child's first name), expired or not found. Limited to 60 a hour per member. | `GET /me/children/link/{code}` |
| **Accept** | A parent uses an invite: the invite row becomes the active link. | `POST /me/children/link/{code}` |
| **Revoke** | End an active link: the parent ends theirs, or the child removes a parent. The row records who. | `DELETE` routes; `revoked_by` |
| **Removed by the child** | A link the child revoked. The parent returns only through an invite from someone who manages parents for the child's gender. | `RemovedByChildBlocksAsync` |
| **Child lock** | The transaction-level advisory lock on the child's user id that keeps one active link per pair and one use per invite. | `GuardianLock`, class 3001 |

## Words we do not use

- "Student" for a member in this domain: a **student** is defined by a class (`classes`); here it is a **member**.
- "Guardian" for the person: the person is a **parent**; **guardian link** is the record (and `guardian` is one allowed relationship word).
- "Delete" for a revoke: a revoked link stays as a row.
