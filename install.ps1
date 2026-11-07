# Jhon's installer for Windows, through WSL:
#   irm https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.ps1 | iex
# A specific release:
#   $env:JHON_VERSION = '0.1.0'; irm https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.ps1 | iex
# A distro other than the default one:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.ps1))) -Distro Ubuntu-24.04
#
# Jhon v0.1 runs on Linux; on Windows it runs inside WSL 2 (native Windows
# comes in v0.2). This script installs nothing on Windows: it checks that WSL
# is present, that the distro exists and runs as WSL 2, that it is Linux and
# has curl, then runs the Linux installer (install.sh) inside it. With a
# console attached, wsl.exe gives the distro a terminal, so install.sh opens
# `jhon setup` there. Windows PowerShell 5.1 or later.
param(
    [string]$Distro = ''
)

# The body runs in its own script block: through `irm | iex` the script runs in
# the caller's scope, and StrictMode, the error preference and these functions
# must not stay in the user's session.
& {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $InstallShUrl = 'https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh'
    # The same form as install.sh's valid_version (S11): X.Y.Z or X.Y.Z-rc.N, no leading
    # zeros. \z, not $, which also matches before a trailing newline; -cnotmatch,
    # because -notmatch ignores case.
    $VersionPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.(0|[1-9][0-9]*))?\z'
    # A distro name as wsl.exe lists it: no spaces or shell characters.
    $DistroPattern = '^[A-Za-z0-9][A-Za-z0-9._-]*\z'

    function Say([string]$Message) { Write-Host "jhon: $Message" }

    # Fail prints the message and stops with code 1 (wsl.exe's own code when given).
    function Fail([string]$Message, [int]$Code = 1) {
        [Console]::Error.WriteLine("jhon: $Message")
        throw (New-Object System.Management.Automation.RuntimeException "jhon-exit:$Code")
    }

    # Wsl runs wsl.exe and returns its output as lines; wsl.exe writes UTF-16
    # unless WSL_UTF8 is set, so NULs are dropped either way.
    function Wsl {
        # Under 'Stop', Windows PowerShell 5.1 turns any stderr line of a native
        # command redirected with 2>&1 into a terminating error; the exit code decides.
        $ErrorActionPreference = 'Continue'
        $out = & wsl.exe @args 2>&1
        $lines = @()
        foreach ($line in @($out)) {
            $text = ([string]$line) -replace "`0", ''
            if ($text.Trim() -ne '') { $lines += $text.TrimEnd() }
        }
        return , $lines
    }

    function Install-Jhon([string]$Distro) {
        $env:WSL_UTF8 = '1'

        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            Fail ("WSL is not installed. Jhon v0.1 runs on Windows inside WSL 2 (native Windows comes in v0.2).`n" +
                "  Install it from an administrator PowerShell, then restart Windows:`n" +
                "    wsl --install`n" +
                "  Then run this installer again.")
        }

        $null = Wsl --status
        if ($LASTEXITCODE -ne 0) {
            Fail "wsl.exe --status failed (exit $LASTEXITCODE): WSL is not ready. Run 'wsl --install' from an administrator PowerShell, restart, and try again."
        }

        # `wsl -l -v` lists every distro with its WSL version; the default one starts with '*'.
        $listing = Wsl -l -v
        $distros = @()
        foreach ($line in $listing) {
            $m = [regex]::Match($line, '^\s*(\*?)\s*(\S+)\s+\S+\s+(\d+)\s*$')
            if ($m.Success -and $m.Groups[2].Value -ne 'NAME') {
                $distros += New-Object PSObject -Property @{
                    Name    = $m.Groups[2].Value
                    Default = ($m.Groups[1].Value -eq '*')
                    Version = [int]$m.Groups[3].Value
                }
            }
        }
        if ($LASTEXITCODE -ne 0 -or $distros.Count -eq 0) {
            Fail ("WSL has no Linux distribution installed.`n" +
                "  Install one (Ubuntu by default) from an administrator PowerShell, then restart Windows:`n" +
                "    wsl --install`n" +
                "  Open the distro once to create your user, then run this installer again.")
        }

        $target = $null
        if ($Distro -ne '') {
            if ($Distro -notmatch $DistroPattern) { Fail "not a WSL distro name: $Distro" }
            foreach ($d in $distros) { if ($d.Name -eq $Distro) { $target = $d } }
            if ($null -eq $target) {
                Fail "no WSL distro named $Distro (installed: $(($distros | ForEach-Object { $_.Name }) -join ', '))"
            }
        } else {
            foreach ($d in $distros) { if ($d.Default) { $target = $d } }
            if ($null -eq $target) {
                Fail "WSL has no default distro. Pick one with 'wsl --set-default <name>' or run this with -Distro <name>."
            }
        }
        $name = $target.Name
        $pick = @('-d', $name)

        if ($target.Version -ne 2) {
            Fail ("$name runs as WSL $($target.Version); Jhon needs WSL 2. Convert it with:`n" +
                "    wsl --set-version $name 2")
        }

        $os = Wsl @pick -e uname -s
        if ($LASTEXITCODE -ne 0 -or $os.Count -eq 0 -or $os[0] -ne 'Linux') {
            Fail "$name did not answer 'uname -s' with Linux; open it once with 'wsl -d $name' and try again."
        }
        $null = Wsl @pick -e sh -c 'command -v curl'
        if ($LASTEXITCODE -ne 0) {
            Fail "$name has no curl. Install it inside the distro (Ubuntu/Debian: sudo apt install curl), then run this again."
        }

        $envPrefix = ''
        if ($env:JHON_VERSION) {
            if ($env:JHON_VERSION -cnotmatch $VersionPattern) {
                Fail "JHON_VERSION must be X.Y.Z or X.Y.Z-rc.N (no 'v', no leading zeros): $($env:JHON_VERSION)"
            }
            $envPrefix = "JHON_VERSION=$($env:JHON_VERSION) "
        }
        $command = "curl -fsSL $InstallShUrl | ${envPrefix}sh"

        Say "installing Jhon inside WSL ($name): $command"
        # Not captured: the console stays the distro's terminal, so install.sh opens jhon setup.
        $ErrorActionPreference = 'Continue'
        & wsl.exe @pick -e sh -c $command
        $code = $LASTEXITCODE
        if ($code -ne 0) { Fail "the Linux installer failed inside $name (exit $code)" $code }

        Write-Host ''
        Write-Host 'Start Jhon from PowerShell:'
        Write-Host "  wsl -d $name -e jhon start"
        Write-Host "or open $name and run: jhon start"
        Write-Host 'Native Windows (no WSL) comes in Jhon v0.2.'
    }

    $exitCode = 0
    try {
        Install-Jhon $Distro
    } catch {
        $m = [regex]::Match([string]$_.Exception.Message, '^jhon-exit:(\d+)$')
        if ($m.Success) { $exitCode = [int]$m.Groups[1].Value } else { throw }
    }
    $global:LASTEXITCODE = $exitCode
}

# Run as a file, the script exits with the code; through `irm | iex` it only
# sets $LASTEXITCODE, so it does not close the user's PowerShell window.
if ($PSCommandPath) { exit $LASTEXITCODE }
