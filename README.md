# Jhon

Jhon is an agent framework for coding agents. It gives the agent freedom of
execution within safety limits and evidence requirements for delivery.

This repository holds Jhon's releases and installers, and this README is
Jhon's user manual. Jhon's source is private; every release here is built,
signed and published by
[`.github/workflows/release.yml`](.github/workflows/release.yml), which anyone
can read.

## What Jhon does

Jhon works in one of two runtimes:

- Claude Code (`jhon start`). It runs Claude.
- pi (`jhon start pi`). It runs Claude or another provider. Your model
  profile picks the provider (`jhon profile`).

The safety limits are guards on every tool call. A destructive shell command
is refused. An outward-facing one, such as a push to the default branch, is
asked about first. Writes outside the project are refused.

The evidence for delivery is the change's record. Its test fails first (RED)
and passes after (GREEN). A light verify comes before the pull request. A
pull request without that record is stopped, with what is missing.
`jhon audit` checks the sessions afterwards.

### What each runtime guarantees

Not every rule is enforced. `jhon doctor --runtime <name>` prints, per rule
and runtime, how it holds:

| Runtime | Enforced (a hook refuses) | Behavioural (`jhon audit` checks after) | Instruction only |
|---|---|---|---|
| Claude Code | 5 | 9 | 4 |
| pi | 5 | 8 | 5 |

The enforced rules are the safety guard's destructive and outward-facing
rules, the framework boundary, a writer's scope, and the tool list a
sub-agent gets. pi's extra instruction-only rule is isolation: pi has no
audit of a writer leaving its own tree. Each enforced rule holds on the
surface its hook reads; a program that acts on its own is outside it.

## Requirements

- Linux on amd64 or arm64, or Windows with WSL 2 (see below).
- git.
- Claude Code (`claude`) for the Claude Code runtime.
- node for pi.
- engram and codegraph, which Jhon always uses.

`jhon setup` checks each one and says how to fix a missing one.

## Install

Linux (amd64 and arm64):

```sh
curl -fsSL https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh | sh
```

A specific release (`X.Y.Z`, or a pre-release `X.Y.Z-rc.N`):

```sh
curl -fsSL https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh | JHON_VERSION=0.2.0 sh
```

It needs curl (or wget), tar, gzip and sha256sum (or shasum). Without
`JHON_VERSION` it installs the latest release, never a pre-release; while
only pre-releases are published it says so and installs nothing (pick one
on the [releases page](https://github.com/sdsoftwaresas/jhon/releases) and
set `JHON_VERSION`). It checks the tarball's sha256 and, when `cosign` is installed, its keyless
signature against this repository's release workflow; without cosign it
says the signature was not checked (`jhon update` verifies signatures
itself, no cosign needed). Any failed check installs nothing. Then the
release's own `jhon release install` places it under
`~/.local/share/jhon/releases`, links `~/.local/bin/jhon`, and `jhon setup`
opens when a terminal is attached.

### Windows (WSL)

Jhon runs on Windows inside WSL 2; native Windows is not supported yet. From
PowerShell (Windows PowerShell 5.1 or PowerShell 7):

```powershell
irm https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.ps1 | iex
```

It needs WSL 2 with a Linux distro (`wsl --install` from an administrator
PowerShell, then a restart) and curl inside the distro. It installs nothing on
Windows: it checks that WSL answers, that the default distro exists, runs as
WSL 2 and is Linux with curl, then runs the Linux installer above inside it
(`$env:JHON_VERSION` is passed through). `jhon setup` opens in the same
window. Another distro:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.ps1))) -Distro Ubuntu-24.04
```

Then start Jhon with `wsl -e jhon start`, or open the distro and run
`jhon start`.

## First start

1. `jhon setup` opens the setup wizard. Pick the runtimes and the opt-in
   integrations. It checks what they need, writes your settings, and
   installs the runtimes.
2. Open your project and start a session: `jhon start` for Claude Code, or
   `jhon start pi` for pi.
3. `jhon doctor` checks that the installed Jhon is healthy.

## A first change, step by step

A small change, from install to merge. In a session the agents run these
commands. They are shown so you can follow, or run them yourself.

1. Install, then run `jhon setup`.
2. Open your project and start a session: `jhon start pi` (or `jhon start`
   for Claude Code). In the session, `/jhon-ldd init` turns Jhon's method on
   for the project.
3. `jhon status` shows the change in progress and the next step. `jhon risk`
   gives the change's risk tier against the default branch.
4. Make a branch: `git switch -c fix/empty-name`. A small change needs no
   folder. `jhon status` names it after the branch, `fix-empty-name`, and
   keeps its record under the git directory, never in the tree.
5. RED: write the test first, then run `jhon executions run fix-empty-name`
   while it fails.
6. GREEN: make the change, then run `jhon executions run fix-empty-name`
   again once the test passes. The record now shows RED before GREEN.
7. Light verify: the `verify` agent reads the diff and the tests, runs the
   focused tests, and records
   `jhon executions verify fix-empty-name --verdict pass`.
8. The pull request: `gh pr create`. Jhon lets it through only with RED
   before GREEN and a passing light verify of the tree the last run tested.
   Otherwise it says what is missing.
9. Afterwards, `jhon audit --all` checks the recent sessions for refusal
   bypasses, isolation bypasses, untested deliveries and edits before RED.
10. `jhon dashboard` shows the sessions, their audits, the changes and the
    usage on http://127.0.0.1:7480.

## Commands

Each line says what `jhon help` says. `jhon <command> --help` gives a
command's own help.

- `jhon setup`: the setup wizard, on a terminal. It picks the runtimes and
  integrations, checks what they need, writes the settings and installs the
  runtimes.
- `jhon start`: start a Jhon session in Claude Code. Other arguments go to
  claude.
- `jhon start pi`: start a Jhon session in pi. Other arguments go to pi.
- `jhon status`: where a change stands: artifacts, tasks, the last test run,
  notes, and an advisory next step. It never blocks.
- `jhon risk`: the risk tier (passive, medium, high) of the change against
  the default branch, with a reason per file.
- `jhon executions run <change>`: run the change's tests and record the run.
- `jhon executions verify <change> --verdict pass|fail`: record a light
  verify in the change's record.
- `jhon audit <session>` or `jhon audit --all`: audit one session, or every
  recent one, against the behavioural rules. It only reads.
- `jhon dashboard`: a read-only dashboard on http://127.0.0.1:7480.
  Ctrl-C stops it.
- `jhon settings list`: every setting with its value and where it comes from.
- `jhon settings get <key>`: one setting.
- `jhon settings set <key> <value>`: write one setting. A value the schema
  refuses is rejected, with what it accepts.
- `jhon settings migrate`: move older settings to the current form, after a
  backup.
- `jhon profile`: list, show and choose your model profiles
  (`jhon profile list`, `jhon profile show <name>`, `jhon profile use <name>`).
- `jhon update`: install the latest release, verified, or go back to the
  previous one (see Update).
- `jhon doctor`: every health check. It makes no network call.
- `jhon help`: the full usage.

## Update

```sh
jhon update            # install the latest release, verified first
jhon update --check    # only say whether one is available
jhon update --rollback # go back to the previous release
```

`jhon update` verifies the sha256 and the cosign keyless signature inside the
binary; it needs no external tool. Pre-releases (`vX.Y.Z-rc.N`) are never
offered by `jhon update`.

## Verify a release by hand

Each release carries, per arch, `jhon-X.Y.Z-linux-<arch>.tar.gz`, its
`.sha256` and its `.sigstore.json` (a cosign keyless bundle). With the three
files in one directory:

```sh
sha256sum -c jhon-X.Y.Z-linux-amd64.tar.gz.sha256
cosign verify-blob \
  --bundle jhon-X.Y.Z-linux-amd64.tar.gz.sigstore.json \
  --certificate-identity "https://github.com/sdsoftwaresas/jhon/.github/workflows/release.yml@refs/tags/vX.Y.Z" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  jhon-X.Y.Z-linux-amd64.tar.gz
```

The identity is this repository's release workflow at the release's tag; the
issuer is GitHub Actions. A signature from any other repository, workflow or
ref is not Jhon's.

## License

Apache-2.0, copyright Jhon Chavarro: [`LICENSE`](LICENSE). What Jhon ships
that is not its own is listed in `THIRD_PARTY_NOTICES.md`, in each release
tarball.
