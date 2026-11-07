# Jhon

This repository holds Jhon's releases and installers. Jhon's source is
private; every release here is built, signed and published by
[`.github/workflows/release.yml`](.github/workflows/release.yml), which anyone
can read.

## Install

Linux (amd64 and arm64):

```sh
curl -fsSL https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh | sh
```

A specific release (`X.Y.Z`, or a pre-release `X.Y.Z-rc.N`):

```sh
curl -fsSL https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh | JHON_VERSION=0.1.0 sh
```

It needs curl (or wget), tar, gzip and sha256sum (or shasum). Without
`JHON_VERSION` it installs the latest release, never a pre-release. It
checks the tarball's sha256 and, when `cosign` is installed, its keyless
signature against this repository's release workflow; without cosign it
says the signature was not checked (`jhon update` verifies signatures
itself, no cosign needed). Any failed check installs nothing. Then the
release's own `jhon release install` places it under
`~/.local/share/jhon/releases`, links `~/.local/bin/jhon`, and `jhon setup`
opens when a terminal is attached.

### Windows (WSL)

Jhon v0.1 runs on Windows inside WSL 2; native Windows comes in v0.2. From
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

Apache-2.0: [`LICENSE`](LICENSE). Jhon's third-party notices ship in each
release tarball (`THIRD_PARTY_NOTICES.md`).
