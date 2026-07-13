# Domains

This file enumerates the contexts and important domain modules under `lib/beta_sigma/`.

## Accounts

Context: `BetaSigma.Accounts`

Schemas: `Accounts.User`, `Accounts.UserToken`

Responsibility: authentication identity, roles, permissions, sessions, email confirmation, reset tokens, and user administration.

Key functions: `list_users/1`, `get_user_by_email/1`, `get_user_by_email_and_password/2`, `register_user/1`, `update_user_role/3`, `update_user_permissions/2`, `update_user_access/2`, session token helpers, and email/password flows.

Relations: users own projects, tasks, notes, and notifications.

## Pages

Module: `BetaSigma.Pages`

Responsibility: source of truth for protected page keys, labels, sidebar sections, default role permissions, and LiveView-to-page mapping.

Key functions: `all/0`, `keys/0`, `string_keys/0`, `default_keys_for_role/1`, `key_for_view/2`, `sanitize_keys/1`.

## Projects

Context: `BetaSigma.Projects`

Schemas: `Projects.Project`, `Projects.Sprint`, `Projects.Task`, `Projects.TaskAssignee`, `Projects.TaskComment`

Responsibility: delivery projects, sprints, tasks, assignment, comments, project/task mentions, and AI-assisted project planning.

Key functions: project CRUD, `create_project_with_ai/3`, task CRUD, sprint CRUD, workspace task listing, comment listing/creation, and PubSub subscriptions.

Relations: projects belong to users; tasks belong to projects and sprints and can have many assignees.

## Notes

Context: `BetaSigma.Notes`

Schema: `Notes.Note`

Responsibility: shared and personal notes, optionally tied to projects or tasks.

Key functions: `list_notes/2`, `get_note!/2`, `create_note/1`, `update_note/2`, `delete_note/1`.

Relations: notes belong to a creator and may belong to a project or task.

## Notifications

Context: `BetaSigma.Notifications`

Schema: `Notifications.Notification`

Responsibility: in-app notifications and email notification rendering.

Key functions: `create_notification/4`, `list_notifications/2`, `list_unread_notifications/1`, `mark_read/1`, `mark_all_read/1`.

## Support Modules

- `BetaSigma.OpenAI`: OpenAI request and generation helpers used by Projects' AI plan generation.
- `BetaSigma.Automation`: cross-domain automation helpers for task/mention notifications.
- `BetaSigma.Mailer`, `BetaSigma.Resend`, `BetaSigma.EmailTemplate`: outbound mail integration.
- `BetaSigma.Formatting`: money formatting used by Projects.
- `BetaSigma.Uploads`: local upload directory setup.
