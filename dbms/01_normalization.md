# CP1 · Normalization of the Spotify Music Streaming database

This file starts from one big "listening log" sheet and normalizes it step by step:
UNF → 1NF → 2NF → 3NF → BCNF. At every step it shows the tables and the functional
dependencies (FDs). The final 10 tables are the ones in the seed data: `artists`, `albums`,
`tracks`, `track_artists`, `users`, `playlists`, `playlist_tracks`, `streams`, `liked_tracks`,
`artist_follows`.

Every number below was measured on the 10 CSV files in `seed_data.zip` (698,735 rows in total).
Notation: `X → Y` means "X decides Y". <u>Underlined</u> names are the primary key.

---

## 0. What the data has to store

- **Artists**: country, genre, verified flag, monthly listeners.
- **Albums** (album, EP, single, compilation) made by one artist.
- **Tracks** on an album, with disc and track number, length, ISRC, popularity.
- **Track credits**: a track has one PRIMARY artist and sometimes one FEATURED artist.
- **Users**: email, plan, country, birth date.
- **Playlists** owned by a user, with tracks in order. The same track can be added twice.
- **Streams**: every listening event (who, which track, when, how long, platform, where from).
- **Likes** (user likes a track) and **follows** (user follows an artist).

---

## 1. Unnormalized form (UNF): the listening log

If everything sat on one sheet, one row per stream, then stream **367** would look like this
(all values are the real ones from the CSV files):

| column | value |
|---|---|
| stream_id, started_at, ms_played | 367, 2025-01-01 19:11:03+05:30, 79960 |
| platform, source_type, skipped, offline | ANDROID, PLAYLIST, f, f |
| user_id, email, display_name | 14495, nisha.shah14495@gmail.com, Nisha S. |
| user country, birth_date, subscription, created_at | US, 1973-12-15, DUO, 2019-11-21 05:47:47+05:30 |
| track_id, title, duration_ms, explicit, isrc, popularity | 38213, Phir Se - Remix, 109889, f, INASA1238213, 60 |
| disc_no, track_no | 1, 1 |
| album_id, album_title, album_type, release_date, label, upc | 6810, Silent Tapes 56, ALBUM, 2012-11-05, Tips, 100053928390 |
| album artist: artist_id, name, country, genre, is_verified, monthly_listeners | 1934, Arjun Mohan 1934, KR, Pop, f, 10 |
| playlist_id, name, owner, is_public, is_collaborative | 2465, Monsoon Melodies 465, 2572, t, f |
| **track_artists** (many values in one cell) | "1934 Arjun Mohan 1934 (PRIMARY), 1748 The Desert Theory 1748 (FEATURED)" |
| **playlist_tracks** (many values in one cell) | "1: track 28593, 2: track 38213, 3: track 47775, 4: track 57266" (plus who added each and when) |
| **liked_by** (many values in one cell) | "users 14495, 24650" |
| **followed_artists** of the user (many values in one cell) | "1184, 2718" |

In the CSV data, 9,681 of the 67,808 tracks have two credits, so the `track_artists` cell really
holds a list.

**Problems with this sheet**

- Four cells hold **many values** (repeating groups).
- **Update anomaly:** user 14495 has 7 streams, so the email and plan are stored 7 times. Changing
  the email means editing 7 rows. Track 38213 has 5 streams, so its title and ISRC are stored 5 times.
- **Insert anomaly:** 151 of the 3,000 artists have no album and 8 of the 30,000 users have never
  streamed. They cannot be stored on this sheet without empty stream columns.
- **Delete anomaly:** deleting the only stream of a track also deletes everything we know about that
  track, its album and its artist.

To keep the next steps short, the repeated columns are written as groups:

| Group | Columns |
|---|---|
| **U** (user) | email, display_name, country_code, birth_date, subscription, created_at |
| **T** (track) | album_id, disc_no, track_no, title, duration_ms, explicit, isrc, popularity |
| **AL** (album) | artist_id, album_title, album_type, release_date, label, upc |
| **AR** (artist) | artist_name, country_code, primary_genre, is_verified, monthly_listeners, created_at |
| **PL** (playlist) | owner_user_id, name, is_public, is_collaborative, created_at |

(`country_code` and `created_at` appear in both U and AR. They are different columns: the user's
country and the artist's country.)

---

## 2. First Normal Form (1NF)

**Rule:** every cell holds one atomic value and there are no repeating groups.

Each many-valued cell becomes its own table with one row per value:

- **Stream_1NF**(<u>stream_id</u>, user_id, U, track_id, T, album_id, AL, artist_id, AR, playlist_id, PL, started_at, ms_played, platform, source_type, skipped, offline)
- **Credit_1NF**(<u>track_id, artist_id</u>, role, T, AR)
- **PlaylistEntry_1NF**(<u>playlist_id, position</u>, track_id, added_by_user_id, added_at, PL, T)
- **Like_1NF**(<u>user_id, track_id</u>, liked_at, U, T)
- **Follow_1NF**(<u>user_id, artist_id</u>, followed_at, U, AR)

All cells are now atomic. The tables still repeat a lot of data, which the next steps remove.

**Why the key of PlaylistEntry_1NF is (playlist_id, position).** `(playlist_id, track_id)` cannot be
the key, because 1,800 pairs appear more than once (the same track added twice to a playlist).
`(playlist_id, position)` has no duplicates.

---

## 3. Second Normal Form (2NF)

**Rule:** 1NF, and no non-key column depends on only **part** of a composite key.

`Stream_1NF` has a one-column key, so it is already in 2NF. The four composite-key tables:

| Table | Key | FD | Verdict |
|---|---|---|---|
| Credit_1NF | (track_id, artist_id) | `track_id → T` | **partial** |
| | | `artist_id → AR` | **partial** |
| | | `(track_id, artist_id) → role` | whole key ✔ |
| PlaylistEntry_1NF | (playlist_id, position) | `playlist_id → PL` | **partial** |
| | | `track_id → T` | not from the key, handled in 3NF |
| | | `(playlist_id, position) → track_id, added_by_user_id, added_at` | whole key ✔ |
| Like_1NF | (user_id, track_id) | `user_id → U`, `track_id → T` | **partial** |
| | | `(user_id, track_id) → liked_at` | whole key ✔ |
| Follow_1NF | (user_id, artist_id) | `user_id → U`, `artist_id → AR` | **partial** |
| | | `(user_id, artist_id) → followed_at` | whole key ✔ |

We keep only the whole-key columns in each junction table and move the rest out:

- **track_artists**(<u>track_id, artist_id</u>, role)
- **playlist_tracks**(<u>playlist_id, position</u>, track_id, added_by_user_id, added_at)
- **liked_tracks**(<u>user_id, track_id</u>, liked_at)
- **artist_follows**(<u>user_id, artist_id</u>, followed_at)

The moved groups T, AR, U and PL end up in the tables built in the next step.

---

## 4. Third Normal Form (3NF)

**Rule:** 2NF, and no non-key column depends on another non-key column (no transitive dependency).

FDs of `Stream_1NF`:

| FD | Type |
|---|---|
| `stream_id → user_id, track_id, playlist_id, started_at, ms_played, platform, source_type, skipped, offline` | direct ✔ |
| `user_id → U` | **transitive** (stream_id → user_id → email) |
| `track_id → T` | **transitive** |
| `album_id → AL` | **transitive** (stream_id → track_id → album_id → album_title) |
| `artist_id → AR` | **transitive** (… → album_id → artist_id → artist_name) |
| `playlist_id → PL` | **transitive** |

Each transitive group becomes a table, and the old table keeps only the foreign key:

- **artists**(<u>artist_id</u>, artist_name, country_code, primary_genre, is_verified, monthly_listeners, created_at)
- **albums**(<u>album_id</u>, artist_id → artists, album_title, album_type, release_date, label, upc)
- **tracks**(<u>track_id</u>, album_id → albums, disc_no, track_no, title, duration_ms, explicit, isrc, popularity)
- **users**(<u>user_id</u>, email, display_name, country_code, birth_date, subscription, created_at)
- **playlists**(<u>playlist_id</u>, owner_user_id → users, name, is_public, is_collaborative, created_at)
- **streams**(<u>stream_id</u>, user_id → users, track_id → tracks, playlist_id → playlists, started_at, ms_played, platform, source_type, skipped, offline)

That gives the 10 tables of the seed data.

**Repeated values that are not violations.** `country_code` (5 values), `primary_genre` (10),
`subscription` (5), `platform` (6) and `source_type` (5) repeat a lot, and `tracks.title` has only
66 distinct values in 67,808 rows. But none of them decides another column, so they stay as normal
columns (limited by `CHECK`). A separate table would only make sense if we stored extra data about
them, for example the price of a plan.

**Dependencies found by testing the data.** I tested every pair of non-key columns in every table.
Only three one-column dependencies show up:

| Table | Found | Verdict |
|---|---|---|
| `users` | `created_at → country_code` | **Coincidence.** `created_at` has 29,999 distinct values in 30,000 rows, so almost any column "depends" on it. There is no business rule. |
| `streams` | `playlist_id → source_type` | This is the playlist rule from section 8 (a playlist id exists only for `PLAYLIST` streams). It is a `CHECK`, not a split. |
| `streams` | `ms_played → skipped` | **Real.** `skipped` is true exactly when `ms_played < 30000`, for all 250,000 rows (largest skipped value 28,999 ms, smallest non-skipped 55,899 ms). A non-key column decides another non-key column. |

**Result: 9 tables are in 3NF. `streams` is not, because of `ms_played → skipped`. We keep it on
purpose (see section 6).**

---

## 5. Boyce–Codd Normal Form (BCNF)

**Rule:** for every non-trivial FD `X → Y`, `X` is a candidate key. Alternate keys count as determinants too.

| Table | Candidate keys | Main FDs | BCNF? |
|---|---|---|---|
| artists | `artist_id` | `artist_id → all` | ✔ |
| albums | `album_id`, `upc` | each → all | ✔ |
| tracks | `track_id`, `isrc`, `(album_id, disc_no, track_no)` | each → all | ✔ |
| track_artists | `(track_id, artist_id)` | → `role` | ✔ |
| users | `user_id`, `email` | each → all | ✔ |
| playlists | `playlist_id` | `playlist_id → all` | ✔ |
| playlist_tracks | `(playlist_id, position)` | → `track_id, added_by_user_id, added_at` | ✔ |
| streams | `stream_id` | `stream_id → all`, **and** `ms_played → skipped` | **✘** `ms_played` is not a key |
| liked_tracks | `(user_id, track_id)` | → `liked_at` | ✔ |
| artist_follows | `(user_id, artist_id)` | → `followed_at` | ✔ |

- **tracks** is the interesting one. It has three candidate keys: the id, the ISRC, and the position
  on the album (`album_id, disc_no, track_no`, with 0 duplicates). All three decide the whole row,
  so every determinant is a key.
- `albums.upc`, `tracks.isrc` and `users.email` are unique in the data, so they are alternate keys.
  We still use the numeric id as the primary key, because emails and codes can be corrected later.
- `artists.artist_name` is unique in this export (3,000 of 3,000), but it is not a key: names can
  be edited and two real artists can share a name.

**Result: 9 tables are in BCNF. `streams` is not, for the same reason as in 3NF.**

---

## 6. Deliberate denormalization (and why)

Three things are redundant. We keep all three, each with a guard.

| Column | Redundant with | Why we keep it | Guard |
|---|---|---|---|
| `streams.skipped` | `ms_played` (`skipped = ms_played < 30000`) | The skip rate is calculated over the biggest table. A stored flag avoids repeating the 30-second rule in every query. Removing it would be the "pure" fix and would put `streams` in BCNF. | `CHECK (skipped = (ms_played < 30000))` |
| `artists.monthly_listeners` | distinct users in `streams` joined with `track_artists`, last 28 days from 3 Jun 2026 | **Derived data.** It matches the recount for all 3,000 artists (the recount counts both PRIMARY and FEATURED credits). The artist page needs it instantly, and recomputing it scans all streams. It goes stale between nightly refreshes. | nightly recompute (query W04) |
| `albums.artist_id` | the `PRIMARY` row in `track_artists` | For all 67,808 tracks, the primary artist is the album's artist. Keeping `albums.artist_id` gives album → artist without a join through tracks. | integrity check below |

Check for the third one. It must return 0 rows (it does on the seed data):

```sql
SELECT t.track_id
FROM tracks t
JOIN albums a ON a.album_id = t.album_id
JOIN track_artists ta ON ta.track_id = t.track_id AND ta.role = 'PRIMARY'
WHERE ta.artist_id <> a.artist_id;
```

---

## 7. Final tables

| # | Table | Primary key | Foreign keys | Rows |
|---|---|---|---|---:|
| 1 | artists | artist_id | | 3,000 |
| 2 | albums | album_id | artist_id → artists | 12,000 |
| 3 | tracks | track_id | album_id → albums | 67,808 |
| 4 | track_artists | (track_id, artist_id) | track_id → tracks, artist_id → artists | 77,489 |
| 5 | users | user_id | | 30,000 |
| 6 | playlists | playlist_id | owner_user_id → users | 10,000 |
| 7 | playlist_tracks | (playlist_id, position) | playlist_id → playlists, track_id → tracks, added_by_user_id → users | 120,004 |
| 8 | streams | stream_id | user_id → users, track_id → tracks, playlist_id → playlists (nullable) | 250,000 |
| 9 | liked_tracks | (user_id, track_id) | user_id → users, track_id → tracks | 58,533 |
| 10 | artist_follows | (user_id, artist_id) | user_id → users, artist_id → artists | 69,901 |
| | **Total** | | | **698,735** |

All 15 foreign keys were checked against the CSV files: 0 orphan rows.

---

## 8. Rules the database should enforce

| Rule | Constraint |
|---|---|
| Each table has the primary key from section 7 | `PRIMARY KEY` |
| Every reference points to a real row | `FOREIGN KEY ... REFERENCES` |
| One UPC per album, one ISRC per track, one email per user | `UNIQUE` on `albums.upc`, `tracks.isrc`, `users.email` |
| One track position per album | `UNIQUE (album_id, disc_no, track_no)` |
| The same track may be on a playlist twice | **no** `UNIQUE (playlist_id, track_id)` |
| `playlist_id` is NULL for 137,386 streams. It is filled for all 112,614 `PLAYLIST` streams and empty for the others | `playlist_id` nullable, `CHECK ((source_type = 'PLAYLIST') = (playlist_id IS NOT NULL))` |
| A skipped stream is a short stream | `CHECK (skipped = (ms_played < 30000))` |
| A collaborative playlist is never public | `CHECK (NOT (is_collaborative AND is_public))` |
| Credit role has two values | `CHECK (role IN ('PRIMARY', 'FEATURED'))` |
| Album type has four values | `CHECK (album_type IN ('SINGLE', 'EP', 'ALBUM', 'COMPILATION'))` |
| Subscription has five values | `CHECK (subscription IN ('FREE', 'PREMIUM', 'DUO', 'STUDENT', 'FAMILY'))` |
| Stream source has five values | `CHECK (source_type IN ('PLAYLIST', 'ALBUM', 'ARTIST', 'RADIO', 'SEARCH'))` |
