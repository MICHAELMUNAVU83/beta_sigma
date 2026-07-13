# Authentication and Authorization

Authentication is based on the generated Phoenix accounts pattern plus project-specific roles and page permissions.

## User Model

Schema: `BetaSigma.Accounts.User`

Fields:

- `name`
- `email`
- `role`, one of `:admin`, `:staff`
- `avatar_url`
- `permissions`, an array of page-key strings
- `hashed_password`
- `confirmed_at`

Passwords are hashed with Bcrypt in `Accounts.User.registration_changeset/3`.

## Sessions

`BetaSigmaWeb.UserAuth` handles:

- Login via `log_in_user/3`
- Logout via `log_out_user/1`
- Session and remember-me cookie lookup via `fetch_current_user/2`
- LiveView mounts for current-user assignment, authentication enforcement, role enforcement, and page access enforcement

Session tokens are stored in `users_tokens` via `Accounts.UserToken`.

## Route Pipelines

Router pipelines:

- `:browser`: session, CSRF, secure headers, flash, root layout, and `fetch_current_user`.
- `:api_session`: JSON, session, CSRF, and `fetch_current_user`.
- `:require_admin`: `BetaSigmaWeb.Plugs.RequireRole` for `[:admin]`.
- `:require_internal_user`: role check for `[:admin, :staff]`.

Live sessions add equivalent `on_mount` checks:

- `:mount_current_user`
- `:ensure_authenticated`
- `{:ensure_role, roles}`
- `:ensure_page_access`
- `:redirect_if_user_is_authenticated`

## Roles and Page Permissions

Roles gate broad areas:

- `:admin`: admin and internal workspace.
- `:staff`: internal workspace only.

Page permissions are managed by `BetaSigma.Pages`. Each protected LiveView/action maps to a page key through `Pages.key_for_view/2`. `Accounts.User.can_access?/2` allows admins automatically; staff users must have the key stored in their `permissions` array.

Default permission keys:

- Admin: all pages whose `default_roles` include `:admin`.
- Staff: workspace pages whose `default_roles` include `:staff`.

## Adding a New Protected Page

1. Add the LiveView route under the right scope in `router.ex`.
2. Add a page entry in `BetaSigma.Pages.@pages` with key, label, path, section, badge, and default roles.
3. Add a `{LiveViewModule, live_action} => :page_key` entry in `Pages.@view_map`.
4. Grant the page to existing non-admin users if needed through Admin Users.

## Adding a New Role

1. Add the role atom to `Accounts.User`'s `Ecto.Enum`.
2. Update broad role checks in `router.ex` and `UserAuth.signed_in_path/1`.
3. Update `BetaSigma.Pages` default roles.
4. Update user management UI and tests.
5. Add seed coverage if the role is meant for contributors.

## PIN or Secondary Auth

No PIN or secondary-auth mechanism exists in the inspected codebase.
