# Task Manager

A focused Flutter task manager with a clean dashboard, Supabase account sign-in,
and per-user task storage. Hive keeps a local cache on the device.

## Features

- Create, edit, complete, and delete tasks.
- Add optional notes, a due date and time, and a low, medium, or high priority.
- Search task names and notes, and filter between all, to-do, and completed tasks.
- Review completion progress and identify overdue tasks at a glance.
- Clear completed tasks or remove all tasks after confirmation.
- Sign up or sign in with email and password.
- Sync each account's tasks with Supabase; Hive caches tasks on the device.

## Connect to Supabase

1. Create a Supabase project.
2. In the Supabase SQL Editor, run [`supabase/schema.sql`](./supabase/schema.sql)
   to create or update the `tasks` table and enable row-level security. If you
   already created the table, run the script again to add newer columns such as
   `priority`; the script is safe to rerun.
3. Copy the project URL and the **publishable/anon key** from the project's API
   settings. Never use a `service_role` key in the app.
4. Run the app with the project values supplied at build/run time:

```powershell
flutter run "--dart-define=VITE_SUPABASE_URL=https://your-project-id.supabase.co" "--dart-define=VITE_SUPABASE_PUBLISHABLE_KEY=your-publishable-key"
```

Replace the sample URL and key with your project's values; do not include
angle brackets around them.

The app requires both defines. If email confirmation is enabled in Supabase,
new users must confirm their email before signing in. Existing Hive tasks are
uploaded to the first signed-in account when that account has no cloud tasks.
Signing out clears the local task cache from the device.

## Run locally

```bash
flutter pub get
```

Run the application with the Supabase command above (Android and web are
supported).

Run the widget tests with:

```bash
flutter test
```

## Project structure

- `lib/main.dart` initializes Hive and Supabase, handles authentication, and
  defines the app theme.
- `lib/models/task.dart` defines the persisted task model.
- `lib/data/hive_data_store.dart` synchronizes authenticated tasks with
  Supabase and caches them in Hive.
- `lib/view/auth/` contains the email/password sign-in and sign-up screen.
- `supabase/schema.sql` defines the tasks table and ownership policies.
- `lib/view/home/` contains the dashboard and task cards.
- `lib/view/tasks/` contains the create and edit form.
