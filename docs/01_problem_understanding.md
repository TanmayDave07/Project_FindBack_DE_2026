# Problem Understanding – Spotify Music Streaming Database

## 1. Problems, Stakeholders and Classification

| ID | Business need | Stakeholder(s) | Related queries | Classification |
|---|---|---|---|---|
| **P1** | Artist pages, album pages and playlists must open fast, even for very popular artists, so browsing and playback feel instant. | Listeners (Free and Premium); Listener App team | R01, R02, R05 | Customer-facing / real-time |
| **P2** | Search, Recently Played and Liked Songs must stay responsive for heavy listeners with long histories and many likes. | Heavy listeners (Free and Premium); Listener App team | R03, R04, R06, W01, W02 | Customer-facing / real-time |
| **P3** | Artists need near real-time Spotify for Artists stats: skip rates, fans-also-like and listener counts. | Artists; Spotify for Artists team | R08, R15, R16, W04 | Real-time for R08 and R15; R16 and W04 are batch/analytics |
| **P4** | Royalty reports must apply the 30-second rule exactly, and rights holders must find a recording by ISRC quickly and exactly. | Royalties/Finance; labels and rights holders | R07, R21, R24, W05 | **Mixed:** royalty reports (R07, R24) = analytics; ISRC lookup (R21) = real-time |
| **P5** | The "public playlists never played" report must return the correct list; today it wrongly returns nothing. | Curation team | R13 | Reporting / analytics |
| **P6** | Wrapped, Release Radar and new-release discovery must be prepared on time. | Personalization team; listeners receiving recommendations | R09, R11, R25 | **Mixed:** Release Radar (R11) = real-time per user; Wrapped and discovery (R09, R25) = batch/analytics |
| **P7** | Compliance must be able to find explicit tracks streamed by minors. | Compliance team; minors (users under 18) | R12 | Reporting / analytics |
| **P8** | Playlist actions (add track, collaborative stats, duplicate clean-up) must be fast. | Playlist users (including collaborators); Playlists team | R14, R22, W03 | **Mixed:** adding tracks (W03) = real-time; collaborative stats and duplicate clean-up (R14, R22) = analytics |
| **P9** | Growth and platform analytics (upsell list, daily streams, offline share, hourly patterns, artist report) must not time out, even at 20× stream volume. | Growth team; Platform/Analytics team | R10, R17, R18, R19, R20, R23 | Reporting / analytics |

## 2. Assumptions

1. "Real-time" means low-millisecond responses on the seed data and the README targets on the large data (e.g. under 5 ms for listener-facing queries, under 250 ms for interactive artist tools). Analytics queries have a looser target (seconds).
2. **P5 / R13:** the empty result is likely a NULL-handling bug. `streams.playlist_id` is NULL for non-playlist streams, and `NOT IN` over a list containing NULL never returns true. This is to be verified and fixed in Phase 4 (e.g. with `NOT EXISTS`).
3. **P7 / R12:** a user's age is calculated at the time of the stream, not today's date.
4. Streams under 30 seconds earn no royalties but still count as streams for analytics (skip rate, listeners, daily counts).
5. The 20× growth applies to stream volume, and the same queries must keep working at that scale.