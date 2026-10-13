# Apartment App agent instructions

These instructions apply to the entire Apartment App repository (Flutter and
Firebase, Group 2, FIG 2026, HES-SO Valais-Wallis).

## Required sources and architecture

- **Use `architecture.md` at all times.** The tracked document in this repository
  is [ARCHITECTURE.md](ARCHITECTURE.md); use that exact filename on case-sensitive
  systems. Read it before planning or changing
  project files, follow it throughout implementation, and check every proposed
  change against it before delivery. Respect its folder structure, component
  responsibilities, dependencies, data flow, navigation, and conventions.
- Locate the existing architecture document if it is not at the repository root.
  If it is missing, report that fact and request its location or creation before
  making architecture-dependent implementation decisions. Do not invent a
  replacement architecture or silently treat the README as its substitute.
  Independent documentation and read-only investigation may continue.
- Read the complete version control plan and all sheets of the sprint workbook
  supplied for the task. Use the workbook for actual story IDs, ownership,
  acceptance criteria, sprint tasks, and the Definition of Done.
- Source plan: `Version Control Plan - Apartment App`, dated October 1, 2026,
  by @Vuk, seven pages. The supplied filename uses an en dash:
  `Version Control Plan – Apartment App.pdf`. Known local locations are
  `../Version Control Plan – Apartment App.pdf` and
  `C:/Users/Jeremy C/Downloads/Version Control Plan – Apartment App.pdf`.
- Current workbook:
  `C:/Users/Jeremy C/Downloads/ProductBacklog_FIG_2026_Apartment.xlsx`.
  These machine-specific locations identify the supplied sources; if unavailable,
  request the current source location rather than assuming stale requirements.
- Explicit current user instructions take precedence over project documents.
  The strategy below incorporates the user's story-number override and clearly
  distinguishes historical PDF examples from current story assignments.

## Scope, preservation, and operating restrictions

- Implement only assigned stories and their necessary integration points.
  Preserve other students' work and unrelated local changes. Inspect `git status`
  before editing, switching branches, staging, or committing. Use an isolated
  worktree when needed; do not reset, discard, or automatically stash others' work.
- Preserve the verified-email login gate implemented for actual US 6/7. Changes
  to authentication, routing, or protected features must retain that behavior.
- Keep each story's actual US number in branch names, commits, relevant code
  references, tests, PRs, and documentation. Do not substitute its priority rank.
- Follow the user's current operating restrictions. When a session is local only,
  do not push, open a PR, deploy Firebase rules, or merge into shared branches
  unless the user explicitly changes that restriction. Describe unperformed
  review, device, and acceptance checks accurately. A one-time authorized exception
  does not authorize future releases
  or other remote actions.
- The remote commands below document the team's normal workflow. They are not
  permission to execute remote actions during a restricted session. If fetching
  or pulling is unavailable, branch from the current local `develop` and report
  that its freshness relative to the remote has not been verified.

## Complete version control strategy

### Purpose and goals

Every backlog item is developed on its own branch, enters `develop` through a
reviewed pull request, and reaches `main` only as a tested release. The plan applies
to `dace4/apartment-app` and fulfills the Sprint 0 task to formulate and document
the Git branching strategy.

- `main` must always build and be suitable for the Google Play closed beta.
- `develop` must contain the latest integrated sprint work and build without errors.
- Every change must be traceable to a backlog story or an identified setup task.

### Branch model

| Branch | Lifetime and purpose | Starts from | Integrates into | Ownership |
| --- | --- | --- | --- | --- |
| `main` | Permanent; released code, tagged Play beta builds | Initial repository | Release baseline | No direct commits; release and hotfix PRs only |
| `develop` | Permanent; integrated, working sprint features | `main` at initial setup | Sprint release | No direct commits; reviewed PRs only |
| `feature/*` | One backlog story; delete after merge | Current `develop` | `develop` | Assigned developer |
| `fix/*` | One bug-fix item; delete after merge | Current `develop` | `develop` | Assigned developer |
| `chore/*` | One setup, CI, dependency, or maintenance task | Current `develop` | `develop` | Assigned developer |
| `release/*` | A few days per sprint; version bump and final fixes only | `develop` | `main`, then back into `develop` | Team; bug fixes only after version preparation |
| `hotfix/*` | Hours; urgent beta fix | `main` | `main`, then back into `develop` | Developer fixing the issue |

Each story branches from `develop` and returns through a PR. At sprint end, a
release branch carries integrated work into `main`; tag the release and merge it
back into `develop` so version changes and release fixes are retained.

### Branch naming and story identity

Use `<type>/US-<id>-<short-description>` for story features and fixes. Pad the
**actual `US Nr.` value** to two digits; use lowercase description words joined
by hyphens. This is the user's explicit override of the PDF's Priority-column ID
rule. For example, advertiser contact is `feature/US-12-contact-advertisers`,
even though its priority is 9.

Examples:

- Feature: `feature/US-04-view-apartments`.
- Bug fix: `fix/US-05-empty-filter-message`.
- Chore without a story: `chore/go-router-setup`.
- Release: `release/v0.1.0`.
- Hotfix: `hotfix/v0.1.1-login-crash`.

The PDF's historical Sprint 1 map listed browsing as US-04 (5 SP), filtering as
US-06 (5 SP), account creation as US-07 (8 SP), and login as US-08 (5 SP). Its
authentication dependency required account creation to merge before login, with
the login branch rebased onto the updated `develop` afterward. These are historical
labels and estimates, not current assignments. In the supplied workbook the
corresponding actual story IDs are US-04, US-05, US-06, and US-07; US-08 is apartment
availability. Apply the same dependency principle to actual US-06/US-07, and do
not overwrite current workbook values with the PDF's historical map.

### Feature workflow

One developer owns a feature branch from creation through merge and deletion.

1. Mark the story "In progress" and assign its owner in the backlog or GitHub
   Project board when that external update is authorized.
2. Update local `develop` before branching:

   ```sh
   git checkout develop
   git pull origin develop
   ```

3. Create a branch for that single story:

   ```sh
   git checkout -b feature/US-04-view-apartments
   ```

4. Commit small, working steps using Conventional Commits. Inspect and stage only
   the task's intended files; the PDF's `git add .` example must not include
   unrelated student work. In the normal authorized team workflow, push early:

   ```sh
   git commit -m "feat(US-04): add apartment list screen"
   git push -u origin feature/US-04-view-apartments
   ```

5. Synchronize with `develop` at least daily and whenever someone merges:

   ```sh
   git fetch origin
   git rebase origin/develop
   git push --force-with-lease
   ```

   Rebase only a branch on which you work alone. For a branch shared by two or
   more people, use `git merge origin/develop` instead. Never force-push `main`
   or `develop`; use `--force-with-lease` only for the authorized personal branch
   after rebasing.
6. Before opening a PR, run `flutter analyze`, `flutter test`, and `flutter run`
   on Android. Verify the acceptance criteria and document how to reproduce them.
7. Open a PR from the story branch into `develop` and request at least one other
   team member as reviewer.
8. After approval and resolution of all review comments, **Squash and merge**.
   Delete the branch on GitHub and locally after integration:

   ```sh
   git checkout develop
   git pull origin develop
   git branch -d feature/US-04-view-apartments
   ```

### Commit messages and sensitive files

Use Conventional Commits: `<type>(US-<id>): <what changed>`. Write the subject
in the imperative and keep it under 72 characters. Non-story setup and
documentation tasks may omit the US scope rather than inventing a story number.

| Type | Purpose | Example |
| --- | --- | --- |
| `feat` | New user-facing behavior | `feat(US-05): add price range filter` |
| `fix` | Bug fix | `fix(US-07): redirect to home after login` |
| `refactor` | Code change without behavior change | `refactor(US-04): extract ApartmentCard widget` |
| `test` | Add or change tests | `test(US-06): cover email verification` |
| `chore` | Setup, dependencies, build configuration | `chore: add firebase_auth dependency` |
| `docs` | README and documentation | `docs: add branching strategy to README` |

Never commit secrets, including keystores, `key.properties`, service account
files, or private credentials. Commit Firebase configuration only if the team
agrees that the project's security rules are locked down. Do not assume an
existing configuration file proves that approval or security validation occurred.

### Pull requests, review, and Definition of Done

A feature enters `develop` only through a PR approved by at least one other team
member. Repeat the actual story ID and title in the PR title, link the backlog
item in the description, and list how to test it. The reviewer must pull and run
the branch, not merely read the diff.

Before merging into `develop`, require:

- The story's backlog acceptance criteria are met; for actual US-05, show
  "no results found" when no apartment matches the filters.
- `flutter analyze` reports no errors.
- `flutter test` passes, and new logic has at least one meaningful test.
- The application starts with `flutter run` on Android.
- The branch is current with `develop` and has no conflicts.
- At least one reviewer approves and all review comments are resolved.

Use **Squash and merge** so each story becomes one commit on `develop`, with its
actual story ID in the commit title.

The workbook additionally requires a user guide, a technical guide, code committed
to Git, completed code review, and passed acceptance criteria. Maintain or provide
both guides for implemented stories. Product Owner acceptance ("done done") is a
separate check; do not claim it from automated tests or self-review. Report local
implementation, automated checks, Android execution, team review, integration,
and PO acceptance separately, including any checks still outstanding.

### Sprint releases from develop to main

Release once per sprint after the sprint's stories pass a full test on `develop`.
Every release gets a version tag and supplies the Google Play closed beta build.

1. Freeze `develop` for new features, update it, and create the release branch:

   ```sh
   git checkout develop
   git pull origin develop
   git checkout -b release/v0.1.0
   ```

2. Bump `pubspec.yaml`, for example `version: 0.1.0+1`. Before `+` is the
   version name; after `+` is Android's `versionCode`, which must increase for
   every Play upload. These numbers are examples, not permission to downgrade
   the current project version.
3. Build with `flutter build appbundle --release` and test the release on a real
   device. Commit only bug fixes on the release branch after preparing its version.
4. Open `release/v0.1.0` into `main` as a PR approved by the **whole team**.
5. Use **Create a merge commit**, not squash, then update local `main` and tag:

   ```sh
   git checkout main
   git pull origin main
   git tag -a v0.1.0 -m "Sprint 1: browse, filter, sign up, log in"
   git push origin v0.1.0
   ```

6. Merge `main` back into `develop` through the protected, reviewed integration
   workflow so the version bump and release fixes are retained.
7. Upload the `.aab` built from the tag to the Play Console closed testing track
   and publish a GitHub Release with the changelog when authorized.

Sprint releases increase the minor version (`v0.1.0`, `v0.2.0`), hotfixes increase
the patch (`v0.1.1`), and `v1.0.0` is reserved for the first public release.

### Hotfixes and conflict resolution

For an urgent beta bug, branch from `main` so unfinished sprint work does not
reach testers:

```sh
git checkout main
git pull origin main
git checkout -b hotfix/v0.1.1-login-crash
```

Fix the bug, raise both the patch version and `versionCode` (example `0.1.1+2`),
test it, and open a PR into `main`. After review and merge, tag `v0.1.1`, then
integrate `main` back into `develop`. Follow the protected branch review rules.

Resolve conflicts on your own feature branch, never directly on `develop` or
`main`. If the conflict affects someone else's code, coordinate with its owner;
do not silently choose one student's implementation over another. For dependency
conflicts, preserve both intended sets of changes in `pubspec.yaml`, then run
`flutter pub get` to regenerate `pubspec.lock` rather than hand-editing the lock
file. Run `flutter analyze` and `flutter test` again after every conflict resolution.

### GitHub repository setup

The PDF's initial premise that only `main` existed is historical; inspect the
repository before attempting setup, and do not recreate an existing `develop`.
When initial setup is needed and authorized:

1. Create `develop` from `main` and push it:
   `git checkout -b develop`, then `git push -u origin develop`.
2. Set `develop` as the default branch so new PRs target it automatically.
3. Under Settings > Branches > Add branch ruleset, protect `main`: require a PR
   and at least one approval; block force pushes and deletion. Release approval
   still requires the whole team under the release workflow above.
4. Protect `develop`: require a PR, at least one approval, and an up-to-date branch
   before merging.
5. Enable "Automatically delete head branches" under Settings > General.
6. Allow squash merging and merge commits; disable rebase merging for predictable
   history. This repository merge setting does not prohibit rebasing a personal
   feature branch before review.
7. Optionally add GitHub Actions running `flutter analyze` and `flutter test` on
   every PR and make that workflow a required check.
8. Add the branching summary to the README's Git Workflow section and mark the
   Sprint 0 branching-strategy task complete only when it is actually fulfilled.

### Quick reference

These commands describe the normal workflow; operating restrictions still apply.

| Goal | Commands, in order |
| --- | --- |
| Start a story | `git checkout develop`; `git pull origin develop`; `git checkout -b feature/US-xx-name` |
| Save work | Inspect `git diff`; `git add <intended-files>`; `git commit -m "feat(US-xx): describe change"` |
| Push a branch | `git push -u origin feature/US-xx-name` |
| Update a personal branch | `git fetch origin`; `git rebase origin/develop` |
| Push after personal rebase | `git push --force-with-lease` |
| Inspect the current branch and changes | `git status` |
| Clean up after merge | `git checkout develop`; `git pull origin develop`; `git branch -d feature/US-xx-name` |
| Tag a release | `git tag -a v0.x.0 -m "Release description"`; `git push origin v0.x.0` |

Never commit directly to `main` or `develop`, keep one story per branch, and update
`develop` before branching when the session permits synchronization.
