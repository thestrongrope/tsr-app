# Issue 99: each converted read of `access` and the test in which it returns a row

TC-ACC-R1-03 (inspection). `DbRow` checks a row's shape on the first row, so a read that never returns a row in a test checks nothing (#96).
Counted by reading every `ListAsync` and `ScalarAsync` that runs a SELECT through `Sql` on a `NpgsqlDataSource` or a `DbTx` in `domains/access/api` (not `Migrations/`, not tests): **19 reads**
(the plan counted 19). The `insert ... returning` and the `select pg_advisory_xact_lock` run through `ScalarAsync` and `ExecuteAsync` and are writes, not reads.
Golden scenarios are in `db/tests/AccessGolden*Scenarios.cs`, their answers in `db/tests/golden/access/`. Made by reading the scenarios and the golden bodies, not by logging the statements.

| # | Read | File:line | Returns a row in |
|---|---|---|---|
| 1 | caller's role id | `Permissions.cs:92` | golden `read-super` (`GET /user/permissions`, role 1); `PermissionGrants.ViewAsync` in `admin-perm-reads-super` |
| 2 | catalog names | `Permissions.cs:107` | golden `read-super` (`GET /me/permissions/donors:read` checks the action against the catalog first); `AccessTests` `CanAsync_with_no_target_allows_a_held_action_and_refuses_one_not_held` |
| 3 | stored access of one user | `Permissions.cs:144` | golden `read-super` (`GET /me/permissions`); one row for every signed-in request |
| 4 | live rules of a token | `Permissions.cs:174` | golden `read-assigned-rules` (member 900005 holds two live rules); `TestGrantsTests` `A_rule_takes_effect_on_the_next_request_...` |
| 5 | conditions of those rules | `Permissions.cs:188` | golden `read-assigned-rules` (rule 1 has city, level, tag) |
| 6 | a class access rule by id | `ClassAccessRevoke.cs:112` | golden `class-access-save-revoke` and `write-rule-save-revoke` (`POST /admin/class-access/rules/1/revoke`) |
| 7 | a live named grant, inside the grant transaction | `AdminPermissionGrant.cs:92` | **NONE FOUND** that is deterministic. A second grant is refused earlier, by the held check (`GrantRules.RefuseGrant`), so the golden 409 and `TestGrantsTests` 409 never reach it. Only `TestGrantsTests` `Two_simultaneous_grants_of_one_permission_leave_one_row_and_one_event` can (a request that passed the held check before the winner committed); it does not assert that one did. |
| 8 | a grant by id with its member's token | `AdminPermissionRevoke.cs:77` | golden `admin-perm-grant-revoke`, `write-permission-grant-revoke`; `TestGrantsTests` `A_grant_and_a_revoke_name_the_operator_...` |
| 9 | catalog with descriptions | `PermissionGrants.cs:97` | golden `admin-perm-reads-super` (every member view) |
| 10 | role's permission names | `PermissionGrants.cs:109` | golden `admin-perm-reads-super` (`/admin/permissions/members/900001`, `fromRole` lists the role 1 grants) |
| 11 | a member's live named grants | `PermissionGrants.cs:118` | golden `admin-perm-grant-revoke` (the answer of a grant lists the new grant) |
| 12 | a member by token | `AdminMembers.cs:65` | golden `admin-perm-reads-super` (tokens 900005, 900007, 900008, 900001) |
| 13 | grant screen search | `AdminMembers.cs:96` | golden `admin-perm-reads-super` (`q=Gold`, `q=900008`) |
| 14 | class access screen search | `AdminMembers.cs:125` | golden `class-access-reads-gents` (`q=Gold`, `q=900007`), `ladies-admin-success` |
| 15 | role of a user | `ClassAccessStore.cs:37` | golden `write-rule-save-revoke` (the operator 900002 holds role 3; the member's role is 5 after the first save) |
| 16 | live rules with ids | `ClassAccessStore.cs:41` | golden `write-rule-save-revoke` (second save and both revokes find a live rule); `read-assigned-rules` (`GET /admin/class-access/members/900005`) |
| 17 | conditions of those rules | `ClassAccessStore.cs:56` | golden `read-assigned-rules` (rule 1 has three conditions); `write-rule-condition-order` |
| 18 | class levels | `ClassAccessStore.cs:77` | golden `class-access-reads-super` (`GET /admin/class-access/options` lists 3 levels); `TestGrantsTests` `One_published_view_of_class_levels_serves_...` |
| 19 | count of levels that exist | `ClassAccessStore.cs:115` | golden `ladies-admin-success` (preview with `{"field": "level", "value": 2}`); `write-rule-condition-order` (levels 2 and 3) |

One of 19 has no deterministic test (row 7). Whether to add one (a sequential test cannot reach it: the held check refuses first) is left to the caller.
