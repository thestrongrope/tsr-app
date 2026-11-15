# Guardian links: a parent's and a child's own view

Owner domain: `membership` · Status: live for the six self-service operations, `GET /me/children` and the five staff operations (batch B4b)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
A parent links to a child with a one-time invite. A parent sees and ends their own links; a child sees and removes their own parents. A parent the child removed returns only through an admin's invite, so a child's choice is respected.

## 2. Actors and scope
- **Actors:** a signed-in member as parent (`children:read`, `children:link`) or as child (`parents:manage`); the invite's creator (a staff member or the child) only through the 403 rule.
- **In scope:** `GET /me/children/links`, `GET` and `POST /me/children/link/{code}`, `DELETE /me/children/{child_token}/link`, `GET /me/parents`, `DELETE /me/parents/{parent_token}`.
- **Also in scope (B4b):** `GET /me/children`; staff and child create (`POST`), list (`GET`) and cancel (`DELETE`) invites at `/members/{child_token}/parent-links[/{id}]`; the candidate lookup `GET /members/{child_token}/parents/candidate/{parent_token}`; add by token `POST /members/{child_token}/parents`.
- **Out of scope:** the child-facing class, attendance and performance views (`classes`).

## 3. Requirements (current behaviour)
`D` = `db/tests/GuardianTests.cs`, `MembershipRightsTests.cs`; `U` = `api/domain/GuardianRules.Tests.cs`, `LinkRowView.Tests.cs`; `H` = (B4b: `me-children.hurl`, `member-parent-*.hurl`, `member-parents-add.hurl`), `spec/tests/children-links.hurl`, `children-link-inspect.hurl`, `children-link-accept.hurl`, `children-link-revoke.hurl`, `parents-list.hurl`, `parent-revoke.hurl`.

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| GRD-R1 | IF the caller is not signed in THEN 401; IF the member lacks the operation's permission THEN 403 `You do not have permission to do that` | identity, access | Must | Test: H case 1 of each file; 403: none (section 9) |
| GRD-R2 | WHEN a parent lists links THEN the system SHALL return a bare list of the caller's links (every status), newest first, each row `id, parent_token, child_token, child_name, relationship, status, source, created_at, created_by_name, activated_at, revoked_at` with dates as `Y-m-d H:i:s` (UTC) | PHP's raw row | Must | Test: U `LinkRowViewTests`; D `The_links_list_shows_every_status_newest_first_...`; H children-links 2 |
| GRD-R3 | The system SHALL show `created_by_name` as `Invite link` when the link's source is `link`, otherwise the creator's name or `Unknown`; a name that is empty stays empty; a child with no holder has a null `child_name`; a token two members hold gives one row per member | PHP's two LEFT JOINs | Must | Test: U `LinkRowViewTests`; D `A_child_token_shared_by_two_members_lists_the_link_once_per_member` |
| GRD-R4 | WHEN a child lists parents THEN the system SHALL return the caller's active links with `parent_name` in place of `child_name`, newest first | PHP's `linksForChild` | Must | Test: D `A_child_lists_only_their_active_parents_with_the_parents_name`; H parents-list 2, 3 |
| GRD-R5 | WHEN a member inspects a code THEN the system SHALL answer `{"state": "not_found"}`, `{"state": "expired"}` (used, cancelled or past its expiry) or `{"state": "valid", "first_name": <string or null>}` and write nothing | the invite page before accepting | Must | Test: U `GuardianRulesTests`; D `Inspecting_a_live_invite_...`, `An_unknown_used_cancelled_or_past_invite_...`; H children-link-inspect 2, 3 |
| GRD-R6 | IF a member inspects more than 60 times in an hour THEN the system SHALL answer 429 `Too many lookups; try again later`; every call counts, each member has their own count | stops code guessing | Must | Test: D `Inspecting_writes_nothing_and_the_sixty_first_call_in_an_hour_is_a_429`; U `MemberRateLimit` (shared/api) |
| GRD-R7 | WHEN a parent accepts a live invite with `relationship` father, mother or guardian (trimmed, lower-cased) THEN the system SHALL make the invite row the link (parent token, relationship, status active, activated now) and answer 200 `{child_token, relationship, status: "active"}` | PHP's `activateInvite` | Must | Test: D `Accepting_a_live_invite_activates_it_...`; H children-link-accept 6, 7 |
| GRD-R8 | The system SHALL refuse an accept in this order: unknown code 404 `Invite not found`; used or expired 410 `This link has expired or has already been used`; then 422 `Invalid relationship or self-link not allowed` for a caller whose token two members hold, the caller being the child, the caller being the invite's creator, or a bad relationship; then 404 `Invite not found` for a child nobody holds, 422 for a child two members hold | PHP's order | Must | Test: D `The_refusals_come_in_PHPs_order_...`, `A_caller_whose_own_token_is_shared_...`; H children-link-accept 3, 4 |
| GRD-R9 | IF the child previously revoked this parent (a revoked link whose `revoked_by` is the child) AND the invite's creator lacks `parents:manage` for the child's gender THEN 403 `This person was removed by the child; ask an admin for a new link`; a parent removed by someone else may return | the child's choice | Must | Test: D `A_parent_the_child_removed_needs_an_invite_...`, `A_gents_admin_may_not_bring_back_...`, `A_parent_removed_by_someone_other_than_the_child_...`; H children-link-accept 5 |
| GRD-R10 | IF an active link for the pair exists THEN 409 `An active link already exists for this parent and child` and the invite stays unused | one active link per pair | Must | Test: D `A_second_invite_for_a_pair_that_is_already_linked_...`; H children-link-accept 8 |
| GRD-R11 | The system SHALL take a transaction lock on the child before the locked checks and write, so two accepts at once cannot make two active links for a pair or use one invite twice | PHP locks the child's row; the pair has no key | Must | Test: D `Two_invites_for_one_pair_accepted_at_once_make_exactly_one_active_link` (fails without the lock), `Accepting_a_used_invite_twice_at_once_activates_it_once`; `MembershipRightsTests` |
| GRD-R12 | IF the body of an accept is not valid JSON THEN 422 `Invalid JSON body`, before the code is looked up | PHP reads the body first | Must | Test: D `A_body_that_is_not_JSON_is_a_422_...`; H children-link-accept 2 |
| GRD-R13 | WHEN a member revokes (a parent their link to a child, a child one of their parents) THEN the system SHALL mark every active link of that pair revoked with the caller's user id and the time, and answer 204 with no body; none matched is 404 `Active link not found` / `Active parent link not found` | PHP's `revokeForPair` | Must | Test: D `A_parent_revokes_their_own_active_link_...`, `A_child_revokes_a_parent_and_the_row_records_the_child_...`; H children-link-revoke 4, parent-revoke 4 |
| GRD-R14 | The system SHALL read the token in the path as PHP's `(int)`: "abc" is 0 and matches nothing | PHP's cast | Must | Test: D `Revoking_a_link_that_is_not_there_is_a_404_and_a_non_number_is_token_zero`; H children-link-revoke 2, parent-revoke 2 |
| GRD-R15 | WHEN a caller lists children THEN the system SHALL return their active links in link order, each child with name, first and last name, gender as PHP's integer cast (the word Male is 0) and the active classes they are in (not distinct) | PHP `getChildrenForParent` | Must | Test: H me-children 2, 3 |
| GRD-R16 | WHEN the child (parents:manage) or staff in reach (parents:add) create an invite THEN the system SHALL store one invite (32 hex characters, 7 days, source `link`) and answer 201 `{code, link, url, expires_at}`; IF the child already has 5 live invites THEN 422; a token of 0 or less is 404 before any permission is asked, and an unknown, shared or guest child is 404 `Student not found` | PHP `route_member_parent_links_create` | Must | Test: H member-parent-link-create; D `Concurrent_invites_for_one_child_stop_at_five_under_the_lock`, `A_class_coordinator_may_invite_...`; U `ParentLinkRulesTests` |
| GRD-R17 | The system SHALL list only the caller's own live invites for the child (newest first, at most 5, no code) and let only the creator or a holder of parents:manage for the child's gender cancel one that is still `invited` (an expired one too); anything else is 404 `Invite not found` | PHP `pendingInvitesFor`, `cancelInvite` | Must | Test: H member-parent-links, member-parent-link-cancel; D `Cancelling_is_for_the_creator_or_a_manager_and_never_anyone_else` |
| GRD-R18 | WHEN staff add a parent by token THEN the system SHALL answer 201 with an active `token_entry` link, in PHP's order: staff in reach (else 403 or 404), the body, the parent, the child, a self link or the caller as parent (422), the relationship (422), under the child's lock an existing active link (409), then a pair the child ended (403 `Child previously revoked this parent; admin approval required` unless the caller holds parents:manage for the child's gender) | PHP `addDirect` | Must | Test: H member-parents-add; D `A_direct_add_writes_...`, `A_parent_the_child_removed_returns_only_through_...` |
| GRD-R19 | WHILE a caller holds parents:add-direct the system SHALL answer the candidate lookup with the name only, 30 lookups an hour per caller (429), 404 `Member not found` out of reach, 422 code `ambiguous_token` for a shared token | PHP `candidateLookup` | Must | Test: H member-parent-candidate; D `The_candidate_lookup_follows_the_callers_reach` |

**Quirks copied on purpose** (also in `php-parity-feedback.md`, "Membership batch 3b-2"):

| ID | Quirk | Verification |
|---|---|---|
| GRD-Q1 | Every 422 of the accept carries the one text `Invalid relationship or self-link not allowed`, however different the cause | D `The_refusals_come_in_PHPs_order_...` |
| GRD-Q2 | The route maps the model's status, not its http code: a child nobody holds is 404 `Invite not found`, a shared child 422 | D `The_refusals_come_in_PHPs_order_...` |
| GRD-Q3 | The 403 rule asks whether the invite's creator, not the caller, may manage parents for the child's gender (`(int)` of the stored gender: "Male" is 0) | D `A_gents_admin_may_not_bring_back_...` |
| GRD-Q4 | One revoke ends every active row of a duplicate pair; a revoked row for the pair stays when the pair is linked again | D `One_revoke_ends_every_active_row_of_a_pair_as_PHPs_update_does`, `A_parent_removed_by_someone_other_than_the_child_may_come_back_by_invite` |
| GRD-Q5 | The inspect answer takes the first holder of a token two members hold | none (section 9) |
| GRD-Q6 | The child's later removal of a parent is what makes a return need an admin: `revoked_by` is the child's user id | D `A_child_revokes_a_parent_and_the_row_records_the_child_so_a_return_needs_an_admin` |


## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| GRD-Q7 | Compatibility | The Hurl files of this capability give the same results on PHP and on the new API | store-live builds | Must | Demonstration: `tools/membership-contract.sh parity` and `dev` |
| GRD-Q8 | Security | A code is 32 characters and a longer one is never looked up; the inspect count limits guessing; every query is a prepared statement; no log line carries a member token | CODING-GUIDELINES | Must | Inspection: `api/features/children-link-*/` |
| GRD-Q9 | Reliability | A list is capped at 200 rows (PHP has no cap) | bounded work | Should | Inspection: `api/domain/LinkLister.cs` |

## 5. Rules and permissions
`children:read:self` (list links), `children:link:self` (inspect, accept, revoke as parent), `parents:manage:self` (list and revoke as child): the member set. The one gender-scoped check is GRD-R9, asked of the invite's creator.

## 6. Interfaces
- **API:** the six routes (`spec/api.yaml`; gateway: `= /me/children/links`, `^~ /me/children/link/`, `~ ^/me/children/[^/]+/link$`, `= /me/parents`, `^~ /me/parents/`; `GET /me/children` stays on PHP).
- **Uses:** `UserDirectory` (identity: holders of a token, tokens of user ids), `Permissions` (access).
- **Events:** `membership.parent_invite_created`, `parent_invite_cancelled`, `parent_link_added` (domain `CLAUDE.md`); no notification (PHP sends none).

## 7. Data
Table `membership.user_guardians` (keyed by token, no foreign keys, unique `code`; "one active link per pair" has no key, only the lock). The advisory lock class is 3001 (`GuardianLock`). PII: who is whose parent. Erasure on account deletion: not built (PHP leaves these rows; an open decision for the erasure handler).

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| GRD-D1 | No new unique index; a lock only | old data may hold a duplicate pair (design decision 5) |
| GRD-D2 | `TSR_PUBLIC_WEB_BASE` (configuration, unset means no base) prefixes the invite link `<base>/link/<code>` of the create-invite route | PHP builds it from `REDIRECT_URI` |
| GRD-D3 | The invite code is in no event payload and no log | a code is a bearer secret |

## 9. Known limitations, gaps and open questions
- **Permission 403:** the member set gives every member these permissions and nothing can deny them, so the 403 is not provable end to end.
- **GRD-Q5** has no test.
- **Rate limit** is per API process (several instances would each allow 60).
