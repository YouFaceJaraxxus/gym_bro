# Gym Bro API

Supabase backend for the Gym Bro app: Postgres plus Deno edge functions
(one folder per resource in `supabase/functions/`, Kysely over `pg`). Clients
only talk to the functions; every table has RLS on with no policies, so the
REST API exposes nothing directly.

## Local development

```bash
supabase start                     # Docker stack: Postgres, Auth, Storage, Studio
echo "SEED_PASSWORD='<pick one>'" >> .env.local   # once; the seeded users' password
./scripts/setup_db.sh              # apply the schema and seed demo data
./scripts/serve.sh                 # serve the edge functions with .env.local
```

- API: http://127.0.0.1:54321/functions/v1
- Studio: http://127.0.0.1:54323
- Mailpit (invite and reset emails): http://127.0.0.1:54324

Every seeded user signs in with `SEED_PASSWORD`, read by `setup_db.sh` from
the environment or `.env.local` / `.env`. Users seeded earlier keep their old
password; `./scripts/setup_db.sh --seed-only --reset-passwords` sets them to
the current one.

| Email | Who |
|---|---|
| marcus.bennett@example.com | Owner of Ironclad Fitness (gym) and Peak Performance Supply Co. (shop) |
| elena.vasquez@example.com | Trainer at Ironclad Fitness |
| priya.nair@example.com | Staff (front desk) at Ironclad Fitness |
| liam.oconnor@example.com | Member (friends, chats, posts) |
| sofia.rossi@example.com | Member with a private account |
| ravi.deshmukh@example.com | Staff at Peak Performance Supply Co. |
| chloe.anderson@example.com | Super user (reviews business applications) |
| andrew.foster@example.com | Owner of and trainer at Coastal Barbell Club (a gym with a shop) |
| aisha.mohammed@example.com | Staff and trainer at Ironclad Fitness |
| kenji.tanaka@example.com | Ironclad member whose own gym, Tanaka Judo & Conditioning, is pending review |

There are more seeded people (Summit Strength Collective and Trailhead in
Denver, Coastal in San Diego); `scripts/seed_data.json` has the full cast.

## Roles and businesses

Nobody has a single account type (migration 000023):

- **Everyone is a user**: gym memberships, programmes, meal plans, social.
- **Trainer mode** (`users.is_trainer`): switched on with
  `PUT /users/me/trainer {enabled}`, or by accepting a gym's trainer invite.
  No gym needed; switching it off also leaves every gym they train at.
- **Super user** (`users.is_super_user`): platform admin. Reviews businesses
  and can make others super users (`PUT /users/:id {is_super_user}`).
- **Businesses** are a gym, a shop or both (`has_gym`, `has_shop`), with a
  public profile people can follow. Anyone can apply (`POST /businesses`); it
  stays `pending` until a super user approves it (`GET /businesses/review`,
  `POST /businesses/:id/review {status, note}`; a rejected one can be fixed
  and resubmitted). Owner tools only work once it is `approved`.
- **The team** (`business_member`): `owner`, `staff` or `trainer` at a
  business, several roles per person allowed. Owners invite
  (`POST /businesses/:id/team {user_id | email, role}`) and the person
  accepts or declines (`POST /businesses/:id/invites/:role/accept|decline`, or
  the `business_invite` notification). Owners manage the team, pricing, the
  gym/shop sides and deleting it; staff do the front desk, the shop, the
  profile and posts; trainers post and coach the gym's members. Anyone can
  leave (`DELETE /businesses/:id/team/:userId?role=`) except the last owner.
- Profiles (`/social/users/:id`) show "Owner of" and "Trainer at" (approved
  businesses only); staff roles are never shown. `GET /users/me` (and sign-in)
  include the caller's `businesses` with their roles and `pending_invites`.
- **Training sessions** follow the trainer↔client link, not gyms: a trainer
  logs a session for someone they coach (`POST /training-sessions {user_id}`,
  an accepted client or a member of a gym they work at) and becomes its
  trainer, which lets them edit it and its sets too.
- Super users pass every permission check, and `GET /businesses?all=1` lists
  every business.

### Database console

`/admin/tables` (super users only) reads and writes any table in `public`,
driven by the Postgres catalog: list tables with columns, keys and row
counts; browse rows (`?q=` free text, `?where=` exact JSON filters); insert,
update and delete by primary key (`?pk=` JSON). Before a delete,
`GET /admin/tables/:t/row/impact` lists what cascades, what gets set to null
and what blocks it; `DELETE` needs `expected` (the number of rows the admin
confirmed, so a stale confirmation can't delete more) and `force: true` to
remove the blockers first. Deleting a `users` row also deletes their login.
`admin_audit_log` and `_schema_migrations` are read-only; every write is
logged in `admin_audit_log`. In the app: Home → Admin → Database.

## Social, chat and media

- **People** (`/social/*`): profiles with bio and interests, follows
  (auto-accepted for public accounts, requests for private ones), mutual
  friendships, blocks, reports, people search, ranked suggestions (same gym,
  overlapping check-in times, shared classes, mutual connections, distance,
  interests) and opt-in "nearby" (locations stored rounded to ~1 km, only
  distances are ever returned).
- **Posts** (`/posts/*`): business announcements plus personal photo/video
  posts with per-post visibility (`public` / `followers`; a private account's
  posts are followers-only), a ranked feed (`/posts/feed`, `?mode=explore`),
  ten reaction types on posts and comments, and comment threads up to ten
  levels deep.
- **Chat** (`/chat/*`): direct chats (with message requests per the
  recipient's `who_can_message`), groups with owner/admin roles, replies,
  edits, unsend, reactions, read receipts, mute/archive, and attachments of
  any type up to 50 MB.
- **Stories** (`/stories/*`, migration 000020): a photo/video, text on a
  colour, or something shared (a post, a logged workout or meal, a library
  item, a product — never a person or business). Live for 24 hours for the
  author's audience (followers of a private account, everyone for a public
  one), then kept in the author's archive (`/stories/archive?from=&to=`).
  A tray of followed people (unwatched first), recorded views, likes and
  reactions that notify the author (`story_reaction`), a viewers list for
  the author, and replies / quick emoji reactions that land in the author's
  DMs (`POST /chat/story-replies`, "Reacted 🔥 to your story").
- **Sharing** (`POST /chat/share`, or `share` on any message; stories take
  `share` too): posts, stories, accounts, businesses, products, logged
  workouts/meals and library items. Shares are resolved *for each viewer
  when read* (`_shared/shares.ts`), so a recipient who can't see a private
  post gets `{available: false, reason: "private"}` instead of a preview;
  deleted/archived/blocked → `unavailable`, an old story → `expired`. A
  logged workout or meal is a snapshot only its owner can share. Realtime
  payloads carry shares unresolved; the app fetches `GET /chat/messages/:id`.
- **Archive**: `PUT|DELETE /posts/:id/archive` hides a personal post from
  everyone but its author (profile, feed, shares); `GET /posts/archive`
  lists them by date for the archive calendar.
- **Instagram extras** (migration 000022): saved posts and named
  collections (`/posts/saved`, `/posts/collections`), hashtags parsed from
  captions (`/posts/hashtags`, `GET /posts?hashtag=`), up to three pinned
  posts, per-post "hide like count" / "turn off commenting" / free-text
  location, posts I reacted to (`/posts/liked`), a Reels feed
  (`/posts/feed?mode=reels`), muting someone's posts and/or stories
  (`/social/users/:id/mute`), close friends (`/social/close-friends`) with
  close-friends-only stories and notes, story polls and @mentions, story
  highlights kept on the profile after expiry (`/stories/highlights`), inbox
  notes (`/chat/notes`, 24 hours, replies land in DMs), up to three pinned
  chats, forwarding messages with their files (`/chat/messages/:id/forward`),
  and a website link on profiles.
- **Realtime**: Supabase Realtime private channels authorized by RLS policies
  on `realtime.messages` (migration 000014). `user:<id>` and `chat:<id>` are
  written only by the server (`realtime.send()` in the same transaction as the
  change); clients use `chat-live:<id>` for typing and presence.
- **Private media**: personal post media (`user-media`) and chat attachments
  (`chat-media`) live in private buckets. Clients ask for an upload slot,
  upload straight to Storage with the signed URL, then reference the path;
  reads get short-lived signed URLs, issued only to people allowed to see the
  file. Signed URLs are relative to the Supabase origin (the local edge runtime
  only knows the Docker-internal URL). Unused upload slots are swept by
  `POST /jobs/run`.

## Filling a database

`scripts/setup_db.sh` applies every file in `sql/schemas/` that hasn't been
applied yet (tracked in `public._schema_migrations`), then runs
`scripts/seed.ts`. Both steps are idempotent.

```bash
./scripts/setup_db.sh                # local stack (URLs and keys from `supabase status`)
./scripts/setup_db.sh --reset        # local stack, wiped first (deletes all local data and users)
./scripts/setup_db.sh --migrate-only # schema only
./scripts/setup_db.sh --seed-only    # demo data only
```

Any other database, for example a hosted Supabase project:

```bash
./scripts/setup_db.sh \
  --db-url "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres" \
  --supabase-url "https://<ref>.supabase.co" \
  --service-role-key "<service role key>"
```

The seed creates auth users, so it needs the service role key. A database whose
schema was applied by hand before migration tracking existed is refused; if its
schema is complete, add `--baseline` once to record the files as applied.

### Schema changes

Add a numbered file to `sql/schemas/` (`000014_<name>.sql`), make it
idempotent (`IF NOT EXISTS`), enable RLS on any new table, and extend
`supabase/types/schema/public.ts` by hand. `./scripts/migrate.sh --status`
lists applied and pending files.

## Configuration

Secrets for the functions live in `.env.local` (local) or the Supabase dashboard
(production); see `.env.template`. Everything beyond the database is optional
and switches off cleanly when unset (endpoints answer 503 `not_configured`):

| Variable | Enables |
|---|---|
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `PAYMENTS_CURRENCY`, `PAYMENT_RETURN_URL` | Card payments (webhook: `/functions/v1/payments/webhook`) |
| `FCM_SERVICE_ACCOUNT_B64` | Push notifications |
| `CRON_SECRET` | Scheduled jobs (`POST /jobs/run`, schedule in `sql/cron.sql`) |
| `CHECKIN_SECRET` | Signing gym check-in QR codes (falls back to a derived key) |

## Tests

```bash
deno task check            # type-check every function
deno task lint
deno task test:unit
eval "$(supabase status -o env | grep -E '^(API_URL|ANON_KEY|DB_URL)=')"
export API_URL ANON_KEY DB_URL
export SEED_PASSWORD='<the password the local stack was seeded with>'
deno task test:integration # against the running local stack; cleans up after itself
```

CI (`.github/workflows/ci.yml`) runs all of these on a fresh stack filled with
`setup_db.sh`.

## Deploying

`.github/workflows/deploy.yml` runs after CI passes on a push to `main` (or by
hand from the Actions tab): it applies pending `sql/schemas/` files to the
hosted database with `migrate.sh`, deploys every edge function, smoke-tests
`users/signin`, then builds a release APK against the hosted project and
publishes it as the `android-latest` pre-release. It never seeds. The secrets
it needs are listed at the top of the workflow.

`migrate.sh` records files by name and never re-runs an applied one, so a
change to an already-applied migration must go in a new file; the deploy warns
when it sees one.
