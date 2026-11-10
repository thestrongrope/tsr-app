# platform: glossary

Use these words in code, tests, screens and messages. If a word is missing, add it here first.

| Term | Meaning | In code |
|---|---|---|
| **Feedback** | One message a member sends to the TSR team from the app. Stored once, read later by a reviewer. | table `feedback`; `SubmitFeedback*` |
| **Text** | The words of one feedback message. Trimmed; 1 to 2000 characters, counted as Unicode code points (an Arabic mark counts as one). | `FeedbackText`; JSON `text`; column `message` |
| **Client id** | An id the app makes (a UUID) for one message before it sends it. 1 to 36 letters, digits or hyphens. | `ClientId`; JSON `clientId`; column `client_id` |
| **Replay** | A second send of the same message by the same member with the same client id, usually because the first reply was lost. It returns the stored id; it never stores a second row. | `StoreOnceAsync` |
| **Submitted** | The moment a new feedback row commits. A replay is not a new submission and publishes nothing. | event `platform.feedback_submitted` |
| **Handled** | A reviewer has dealt with the feedback. Not built yet (issue 891). | columns `handled_at`, `handled_by` |
| **Reviewer** | Someone holding `feedback:review:all` (role 1 by default). | permission |
| **Member** | A signed-in user. Defined by `identity` and `membership`; platform only sees the caller's user id. | `Caller.UserId` |
| **Health** | Whether the API process is up. Says nothing about the database. | `GET /health` |
| **App version** | What the app asks at start-up: for each platform the lowest build allowed to run (minimum), the newest installable build (recommended), the store link, and the notes of the recommended release. | `GET /app-version`; `AppCatalog` |
| **Catalog** | The one JSON file the app-version and release-notes answers are read from. A bad file never blocks anyone: it fails open. | `TSR_APP_VERSIONS_FILE`; `AppCatalogSource` |
| **Build** | The integer build number of an app release (the +9 in 1.0.1+9), per platform. Android and iOS count separately. Never the version name. | `minimumBuild`, `recommendedBuild` |
| **Fail open** | When the catalog or part of it is unusable, answer with the permissive default (build 1) instead of an error, so a lost file cannot lock every member out. | `AppCatalog` |
| **Release** | One entry of the catalog's history: version, date, notes, and the build it has on each platform. | `Release`; `GET /release-notes` |
| **Announcement** | An optional notice in the catalog, shown once at start-up; a new id shows it again. | `announcement` |
| **Geo lookup** | A signed-in member's help when filling in a location: the country list, a postal code's state and suggested city, or a city search. Public GeoNames data, never member data. | `GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities` |
| **Postal code lookup** | Finds a state and a suggested city for a country and code. A code with a space is tried whole, then by the part before the space. | `GeoLookup.PostalCodeTries` |
| **Geo call** | Any call to the three geo operations. A member may make 60 in 60 seconds; a call that fails validation still counts. | `MemberRateLimit` (shared/api) |
| **Accent-insensitive** | Equal, and sorted together, whatever the case and accents: "zur" finds "Zürich". The geo name and code columns do this with one collation. | collation `geo_ci_ai` |

## Words we do not use

- "Complaint", "ticket", "support request": it is **feedback**.
- "Message" for the JSON field: the field is **text** (the column is `message` for PHP's sake).
- "Duplicate" for a replay: a replay is expected and correct.
