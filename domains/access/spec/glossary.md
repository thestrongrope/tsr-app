# access: glossary

| Term | Meaning | In code |
|---|---|---|
| **Action** | `resource:action`, with no scope, e.g. `classes:read`. What a handler asks about. | `string action` |
| **Permission** | A full name `resource:action:scope`, e.g. `classes:read:gender`. 102 in the catalog. | `access.permissions` |
| **Scope** | How far a permission reaches: `all`, `gender`, `assigned`, `own`, `taught`, `enrolled`, `self`. | the last part of the name |
| **Target** | What a check is about: nothing, a class, a gender, or a teacher's gender. | `AccessTarget` |
| **Reach** | What a list may show: all, one gender, and/or a set of class ids. | `Reach` |
| **Role** | A number on the user: 0 member, 1 super admin, 3 gents admin, 4 ladies admin, 5 class coordinator, 6 class teacher (unused), 7 finance. | `access.roles`, `access.user_roles` |
| **Named grant** | A permission given to one user, with a reason; held until revoked. | `access.user_permissions` |
| **Class access rule** | Gives a coordinator reach over classes by gender, city, country, level or tag. | `access.class_access_rules` |
| **Member set / own set / taught set** | Permissions held by every member / by someone who teaches or holds an MCQ flag / by someone who teaches. | `PermissionSets` |
| **Guest** | A user with token 0: holds nothing. | `Caller.Token == 0` |
