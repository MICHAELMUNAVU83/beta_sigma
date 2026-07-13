# BetaSigma Todo List

## Foundation

- [x] Confirm target versions for Elixir, Phoenix, LiveView, and PostgreSQL.
- [x] Add missing dependencies: `oban`, `chromic_pdf`, and `bcrypt_elixir`.
- [x] Configure outbound email delivery, `Oban`, PDF generation, and upload/storage settings.
- [x] Add production-ready runtime configuration for mail, storage, and secrets.
- [x] Update project setup documentation and local bootstrap steps.

## Authentication And Authorization

- [x] Generate authentication with `mix phx.gen.auth`.
- [x] Extend users with `name`, `role`, and `avatar_url`.
- [x] Implement role-based authorization plugs and route guards.
- [x] Seed an initial admin user for development.

## Database And Data Model

- [x] Create migrations for users updates and authentication tables.
- [x] Create migrations for projects, tasks, and task assignees.
- [x] Create migrations for task comments and notes.
- [x] Create migrations for notifications.
- [x] Add indexes, unique constraints, and foreign-key delete behavior from the brief.
- [x] Add seed data for users, projects, and sample activity.

## Contexts

- [x] Implement `Accounts` context APIs for users, roles, and staff listing.
- [x] Implement `Projects` context APIs for projects, tasks, assignments, and comments.
- [x] Implement `Notifications` context APIs for create/list/read/unread flows.

## Routing And Web Structure

- [x] Expand the router to include public, auth, internal, and admin routes.
- [x] Add authenticated layouts, shared navigation, and a sidebar component.
- [x] Wire current-user fetching into the browser pipeline.
- [x] Add route-level access control for admin and staff users.

## Phase 1 MVP

- [x] Build projects list, create, edit, and project detail flows.
- [x] Build tasks CRUD and per-project task views.
- [x] Implement kanban drag-and-drop with SortableJS and LiveView events.
- [x] Build notes list/detail/create flows with personal and shared visibility.
- [x] Move note creation and editing into a modal to free space in the notes workspace.

## Real-Time Features

- [x] Broadcast task changes to project subscribers with Phoenix PubSub.
- [x] Subscribe LiveViews to project and notification topics.
- [x] Update task boards and notification counts in real time.

## Phase 3

- [x] Build the in-app notification center and unread badge.
- [x] Add email notification workflows.
- [x] Add Oban workers for task reminders.
- [x] Restyle the account settings page to match the primary workspace design pattern.

## Uploads And Integrations

- [x] Implement local file uploads using the uploads folder.

## Polish And Delivery

- [x] Route all outbound emails through `BetaSigma.Gmail` with branded HTML styling.
- [x] Restore modal-based add and edit flows in the internal workspace and fix sidebar active-page highlighting.
