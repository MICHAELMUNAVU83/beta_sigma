# Portals

Routes are defined in `lib/beta_sigma_web/router.ex`.

## Authentication

Scope: `/users`

Routes:

| Path | Module/controller | Purpose |
| --- | --- | --- |
| `/users/log_in` | `UserLoginLive`, `UserSessionController.create` | Login |
| `/users/log_out` | `UserSessionController.delete` | Logout |
| `/users/reset_password` | `UserForgotPasswordLive` | Request reset |
| `/users/reset_password/:token` | `UserResetPasswordLive` | Reset password |
| `/users/settings` | `UserSettingsLive` | Authenticated settings |
| `/users/settings/confirm_email/:token` | `UserSettingsLive` | Confirm email change |
| `/users/confirm` and `/users/confirm/:token` | confirmation LiveViews | Email confirmation |

Registration routes are commented as removed in the router.

## Internal Workspace

Roles: `:admin` and `:staff`, plus page permissions from `BetaSigma.Pages`.

Scope: `/app`

| Path | LiveView/action | Page key |
| --- | --- | --- |
| `/app/projects` | `ProjectsLive.Index`, `:index` | `:projects` |
| `/app/projects/:id` | `ProjectsLive.Show`, `:show` | `:projects` |
| `/app/sprints` | `SprintsLive.Index`, `:index` | `:sprints` |
| `/app/sprints/:id` | `SprintsLive.Show`, `:show` | `:sprints` |
| `/app/notes` | `NotesLive.Index`, `:index` | `:notes` |
| `/app/notifications` | `WorkspaceLive`, `:notifications` | `:notifications` |
| `/app/chat` | `ChatLive.Index`, `:index` | `:chat` |

## Admin

Role: `:admin`, plus page permissions.

Scope: `/admin`

| Path | LiveView/action | Page key |
| --- | --- | --- |
| `/admin/users` | `AdminUsersLive.Index`, `:index` | `:users` |

## Development

When `config :beta_sigma, dev_routes: true`, `/dev/dashboard` exposes Phoenix LiveDashboard.
