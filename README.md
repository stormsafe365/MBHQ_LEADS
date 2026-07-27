# Lead Tracker — Metal Building HQ

A lightweight shared lead tracker for a small sales team: organize, prioritize, assign, notate, and track leads. Kanban board + sortable list, live-synced between everyone through Supabase. No build step — it's one HTML file.

**Not a CRM.** No contacts database, no email sequences, no reporting suite. Just the pipeline.

## What it does

- **Board view** — drag leads through the pipeline: New Lead → Attempting Contact → Quoted → Active Follow-Up → Future Follow-Up → Ready to Order → Won / Lost / Disqualified
- **List view** — sortable table (click any column header), same filters
- **Prioritize** — call priority on every lead: Hot / Warm / Standard / Long-Term (drives call order, not stage). Nurture = no phone on file, email-only. Hot floats to the top of each column.
- **Assign** — every lead has an owner; "My leads" chip filters to yours
- **Notate** — per-lead notes log with author + timestamp; stage changes and reassignments are logged automatically
- **Track** — next follow-up date per lead; overdue follow-ups turn red and get their own filter chip; stats strip shows open leads, pipeline value, hot count, overdue count, wins
- **Add leads** — quick-add form, or CSV import (file or paste) with automatic column mapping (`leads-import.csv` in this folder is ready to go)
- **Live sync** — changes made by one rep appear for everyone within a second (Supabase Realtime)
- **Logins** — reps sign in with Name + 6-digit PIN (Supabase Auth under the hood)

## One-time setup (~10 minutes)

1. **Create a Supabase project** — go to [supabase.com](https://supabase.com), sign in, **New project** (free tier is fine).

2. **Run the setup script** — in the project dashboard, open **SQL Editor → New query**, paste the entire contents of `supabase-setup.sql` (in this folder), and click **Run**. It creates the `leads`, `lead_notes`, and `profiles` tables, locks them to signed-in users only, and turns on live sync.

3. **Get your keys** — open **Project Settings → API**, copy the **Project URL** and the **anon public** key.

4. **Paste them into the app** — open `index.html` in a text editor (Notepad works), find the `CONFIG` block near the top of the `<script>` section. `COMPANY_NAME` sets the name shown in the header and sign-in card.

5. **Create logins (Name + PIN)** — reps sign in with their **name and a 6-digit PIN**, not a real email. Under the hood each rep is still a Supabase user with a synthetic email, built from their name like this: lowercase, spaces become dots, `@local.com` on the end.

   | Rep signs in as | You create the user with email | Password |
   |---|---|---|
   | `Mike Torres` | `mike.torres@local.com` | their 6-digit PIN |
   | `Jenna` | `jenna@local.com` | their 6-digit PIN |

   In the dashboard: **Authentication → Users → Add user → Create new user** → enter the synthetic email, set the password to the rep's PIN, and check **Auto Confirm User**. PINs must be **6 digits** — Supabase won't accept shorter passwords. Display names come from the email automatically (`mike.torres@…` shows as "Mike Torres"), and capitalization/extra spaces when signing in don't matter.

   Typing a full email address in the Name box also works, if you ever want a real-email account for yourself.

6. **Recommended:** in **Authentication → Sign In / Up**, turn **off** "Allow new users to sign up" — so only accounts you create can get in.

7. **Open `index.html` in a browser and sign in.** Done.

## Loading the leads

`leads-import.csv` (in this folder) contains the cleaned inbound leads from the GHL import workbook — Call Board + Email Nurture combined, with priority, product interest, zip, source, and the full inquiry notes. To load them: sign in → **Import CSV** → **Choose CSV file** → pick `leads-import.csv` → columns auto-map → **Import**. Do this **once**, from one account — everyone shares the same data.

The "Do Not Import" tab from the workbook (duplicates + non-customers) is intentionally left out.

## Sharing it with the team

The file is self-contained — every rep just needs a copy of the configured `index.html` (email it, shared drive, USB, whatever). All data lives in Supabase, so everyone sees the same leads no matter whose copy they open.

If you'd rather have a URL, drop the file on any static host (Cloudflare Pages, Netlify) — it works unchanged.

## CSV import notes

- First row must be headers. Columns are auto-matched by name (`name`, `phone`, `email`, `source`, `interest`, `location`, `value`, `priority`, `stage`, follow-up date, notes) and you can fix any mapping before importing.
- Only **Name** is required; rows without one are skipped.
- A mapped "notes" column becomes the lead's first note.
- Priority accepts `hot/high/urgent`, `warm`, `long-term/dream/cold`, `nurture`; anything else lands as `Standard`. Stage matches by name; unknown stages land in **New Lead**.

## Admin odds and ends (all in the Supabase dashboard)

- **Reset a PIN:** Authentication → Users → the user → update the password to the new 6-digit PIN
- **Remove a rep:** delete the user there; their leads stay, marked Unassigned
- **Backup:** Database → Backups (automatic on free tier, daily)
