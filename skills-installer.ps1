# skillsinstaller.ps1
# Installs popular Agent Skills packs system-wide for Cline (Windows)
# Targets: %USERPROFILE%\.cline\skills  and  %USERPROFILE%\.agents\skills

[CmdletBinding()]
param(
    [switch]$Force,          # Re-download even if already present
    [switch]$SkipLarge,      # Skip the very large agentic-awesome-skills repo
    [string]$CacheDir = "$env:TEMP\cline-skills-cache"
)

$ErrorActionPreference = "Stop"

# ---------- Configuration ----------
$Repos = @(
    @{
        Name     = "anthropics-skills"
        Url      = "https://github.com/anthropics/skills.git"
        Branch   = "main"
        # Skills live in various subfolders; we auto-discover SKILL.md
    },
    @{
        Name     = "obra-superpowers"
        Url      = "https://github.com/obra/superpowers.git"
        Branch   = "main"
    },
    @{
        Name     = "mattpocock-skills"
        Url      = "https://github.com/mattpocock/skills.git"
        Branch   = "main"
    },
    @{
        Name     = "agentic-awesome-skills"
        Url      = "https://github.com/sickn33/agentic-awesome-skills.git"
        Branch   = "main"
        Large    = $true          # Very large – optional
    }
)

$GlobalTargets = @(
    "$env:USERPROFILE\.cline\skills",
    "$env:USERPROFILE\.agents\skills"
)

# ---------- Helpers ----------
function Write-Header($msg) {
    Write-Host "`n=== $msg ===" -ForegroundColor Cyan
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Test-Git {
    try {
        $null = git --version
        return $true
    } catch {
        return $false
    }
}

function Get-SkillFolders($root) {
    # Find every directory that contains a SKILL.md (case-insensitive)
    Get-ChildItem -Path $root -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Directory.FullName } |
        Sort-Object -Unique
}

function Install-SkillsFromRepo {
    param(
        [string]$RepoName,
        [string]$RepoPath,
        [string[]]$Targets
    )

    $skillDirs = Get-SkillFolders -root $RepoPath
    if ($skillDirs.Count -eq 0) {
        Write-Warning "No SKILL.md found in $RepoName"
        return 0
    }

    $count = 0
    foreach ($skillDir in $skillDirs) {
        $skillName = Split-Path $skillDir -Leaf

        # Prefer the folder name that matches the frontmatter name if possible,
        # but fall back to directory name
        $destName = $skillName

        foreach ($targetRoot in $Targets) {
            $dest = Join-Path $targetRoot $destName

            if (Test-Path $dest) {
                if ($Force) {
                    Remove-Item -Recurse -Force $dest
                } else {
                    Write-Host "  Skipping existing: $destName" -ForegroundColor DarkGray
                    continue
                }
            }

            # Copy the entire skill folder
            Copy-Item -Path $skillDir -Destination $dest -Recurse -Force
            $count++
            Write-Host "  Installed: $destName → $dest" -ForegroundColor Green
        }
    }
    return $count
}

# ---------- Main ----------
Write-Header "Cline System-Wide Skills Installer"

if (-not (Test-Git)) {
    Write-Error "Git is required. Install Git for Windows and ensure it is in PATH."
    exit 1
}

# Create cache + target directories
Ensure-Dir $CacheDir
foreach ($t in $GlobalTargets) {
    Ensure-Dir $t
    Write-Host "Target ready: $t"
}

$totalInstalled = 0

foreach ($repo in $Repos) {
    if ($repo.Large -and $SkipLarge) {
        Write-Host "`nSkipping large repo: $($repo.Name) (use without -SkipLarge to include)" -ForegroundColor Yellow
        continue
    }

    Write-Header "Processing $($repo.Name)"

    $repoPath = Join-Path $CacheDir $repo.Name

    if (Test-Path $repoPath) {
        if ($Force) {
            Write-Host "Removing existing cache..."
            Remove-Item -Recurse -Force $repoPath
        } else {
            Write-Host "Updating existing clone..."
            Push-Location $repoPath
            git fetch --depth 1 origin $repo.Branch 2>$null
            git reset --hard origin/$($repo.Branch) 2>$null
            Pop-Location
        }
    }

    if (-not (Test-Path $repoPath)) {
        Write-Host "Cloning $($repo.Url) (shallow)..."
        git clone --depth 1 --branch $repo.Branch $repo.Url $repoPath
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to clone $($repo.Name). Skipping."
            continue
        }
    }

    $installed = Install-SkillsFromRepo -RepoName $repo.Name -RepoPath $repoPath -Targets $GlobalTargets
    $totalInstalled += $installed
    Write-Host "Finished $($repo.Name): $installed skill folders processed"
}

Write-Header "Summary"
Write-Host "Total skill folders installed/updated: $totalInstalled" -ForegroundColor Green
Write-Host ""
Write-Host "Global skill locations:"
$GlobalTargets | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart VS Code / Cline (or start a new Cline task)"
Write-Host "  2. In Cline Settings → Features → make sure Skills are enabled"
Write-Host "  3. Skills will now be available system-wide across all projects"
Write-Host ""
Write-Host "Tip: Run with -Force to force re-download & overwrite"
Write-Host "Tip: Run with -SkipLarge to skip the very large agentic-awesome-skills repo"