# Digital-VLSI Innovation Hub

Team project site for ECE students, GSSSIETW, Mysuru.
Faculty / Mentor: Mrs. Padma R, Assistant Professor, Department of ECE.

This is a separate website from Digital Design Explorer. It links **one way** to Explorer pages
and uses Explorer's accounts. Explorer's files and data are not changed.

## Accounts
- **Students:** log in with their Digital Design Explorer account (USN + email + password).
  If a student is already logged in on Explorer in the same browser, the Hub uses that login automatically.
  New students register on Explorer first.
- **Faculty:** log in with the Explorer **Teacher Login** email and password (the `dde_teachers` accounts).
- Semester and section come from the student's Explorer registration. Values like "5", "5th", "V",
  "Sec A" and "a" are all understood.

## How it works
1. A student creates a team (and becomes the leader) or accepts an invite.
2. The leader invites classmates by USN: **2–4 members, same semester and section only**.
3. The leader selects a project. **One team per project** in the department, so it shows as "Taken" to everyone else.
4. The leader submits the proposal (needs at least 2 accepted members).
5. Faculty approve it, ask for changes (the team keeps the project and resubmits), or reject it (the project is released).
6. After approval, any member ticks shared milestones and posts work updates.
7. At 100%, faculty give final approval and **every member** gets their own certificate with a verifiable ID.

All rules are enforced in Supabase, not only in the browser.

## One-time setup
1. **Supabase → SQL Editor** (the same project as Explorer): paste and run `supabase/hub_setup.sql`.
   It only adds new `hub_` tables and functions, and it is safe to run again.
2. Create a GitHub repository named **InnovationHub** under the same account (padmarmysuru),
   push these files, and turn on GitHub Pages. The site will be at
   `https://padmarmysuru.github.io/InnovationHub/`.
   Keeping it under the same account is what lets students stay logged in across both sites.

`js/config.js` already contains the Explorer Supabase address and public key.

## Explorer links and level locks
- `js/config.js → EXPLORER_TOPICS` maps every learning topic to a real Explorer page.
- Lock badges are read **live** from Explorer's `access-control.js`. When you release a level there,
  the Hub shows it as open automatically, with nothing to change in the Hub.
- While Level 2 is locked, Flip-Flops and Counters open the matching Digital Logic Lab section (Level 1) instead.

## Files
| File | Purpose |
|---|---|
| index.html | Home, workflow, team rules |
| projects.html | Project library with search, filters, Explorer links and "Taken" status |
| login.html | Student login with an Explorer account |
| student.html | My Team: invites, members, project, proposal, milestones, updates |
| faculty.html | Faculty dashboard: approve / changes / reject / unlock / final approve, CSV download |
| certificate.html | Certificates and public verification by ID |
| js/config.js | Settings: Supabase, team size, Explorer topic links, milestones |
| js/data.js | Project catalogue (46 projects) |
| js/hub.js | Shared header, footer, login and helper code |
| supabase/hub_setup.sql | Database tables, security rules and team functions |

## Adding or renaming a project
Edit `js/data.js`, and add the same title to the `hub_projects` list in `supabase/hub_setup.sql`. Then run the file again.
