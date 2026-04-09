# ============================================================
# github-badge-grabber.ps1
# Automatically earn every earnable GitHub Achievement badge.
# Triggers: Quickdraw, Pull Shark, YOLO, Pair Extraordinaire
# Creates a temp repo, triggers all badges, deletes it after.
#
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/Chiragsd13/github-badge-grabber/master/github-badge-grabber.ps1 | iex
#
# Usage (CMD):
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Chiragsd13/github-badge-grabber/master/github-badge-grabber.ps1 | iex"
#
# Requirements: gh CLI installed and authenticated (gh auth login)
# ============================================================

$ErrorActionPreference = "Continue"

# Add common gh CLI install paths so this works from CMD/PowerShell without PATH issues
$ghPaths = @(
    "C:\Program Files\GitHub CLI",
    "$env:LOCALAPPDATA\Programs\GitHub CLI",
    "$env:ProgramFiles\GitHub CLI"
)
foreach ($p in $ghPaths) {
    if (Test-Path "$p\gh.exe") {
        $env:PATH = "$p;$env:PATH"
        break
    }
}

$COAUTHOR = "Chirag Sood <121196981+Chiragsd13@users.noreply.github.com>"
$script:BADGE_REPO = ""
$script:USERNAME = ""
$script:FULL = ""

function Log  { param($m) Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok   { param($m) Write-Host "[+] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "[!] $m" -ForegroundColor Yellow }
function Head { param($m) Write-Host "`n>>> $m" -ForegroundColor White }

function Cleanup {
    if ($script:BADGE_REPO -ne "") {
        Log "Deleting temp repo..."
        gh api "repos/$script:USERNAME/$script:BADGE_REPO" --method DELETE 2>$null | Out-Null
        Ok "Temp repo deleted. No trace left."
    }
}

function Get-MergedPRs {
    # Use search API - avoids GraphQL quoting issues in PowerShell
    return gh api "search/issues?q=is:pr+is:merged+author:$($script:USERNAME)" --jq ".total_count"
}

function Get-DefaultBranch {
    return gh api "repos/$script:FULL" --jq ".default_branch"
}

function Get-HeadSha {
    $db = Get-DefaultBranch
    return gh api "repos/$script:FULL/git/refs/heads/$db" --jq ".object.sha"
}

function Merge-PR {
    param($Branch, $File, $Title)
    $db = Get-DefaultBranch
    $sha = Get-HeadSha

    gh api "repos/$script:FULL/git/refs" --method POST `
        -f ref="refs/heads/$Branch" -f sha="$sha" | Out-Null

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($File))
    gh api "repos/$script:FULL/contents/$File" --method PUT `
        -f message="$Title" -f content="$encoded" -f branch="$Branch" | Out-Null

    $prNum = gh api "repos/$script:FULL/pulls" --method POST `
        -f title="$Title" -f head="$Branch" -f base="$db" --jq ".number"

    gh api "repos/$script:FULL/pulls/$prNum/merge" --method PUT `
        -f merge_method="squash" -f commit_title="$Title" | Out-Null

    Log "PR #$prNum merged."
}

# ============================================================
# PREFLIGHT
# ============================================================
Head "Preflight"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "[-] gh CLI not found. Install from: https://cli.github.com" -ForegroundColor Red
    exit 1
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[-] Not logged in. Run: gh auth login" -ForegroundColor Red
    exit 1
}

$script:USERNAME = gh api user --jq ".login"
Ok "Logged in as: $($script:USERNAME)"

$mergedBefore = Get-MergedPRs

Write-Host ""
Write-Host "  This script will earn you:"
Write-Host "  Quickdraw            " -ForegroundColor Green -NoNewline; Write-Host "open + close an issue instantly"
Write-Host "  Pull Shark           " -ForegroundColor Green -NoNewline; Write-Host "merge 2 pull requests"
Write-Host "  YOLO                 " -ForegroundColor Green -NoNewline; Write-Host "merge without a code review"
Write-Host "  Pair Extraordinaire  " -ForegroundColor Green -NoNewline; Write-Host "co-authored PR with @Chiragsd13"
Write-Host ""
Write-Host "  Creates a temp repo, triggers all badges, then deletes it."
Write-Host ""

$yn = Read-Host "Continue? [y/N]"
if ($null -ne $yn -and $yn.Trim() -ne "" -and $yn.ToLower() -ne "y") { Write-Host "Aborted."; exit 0 }

# ============================================================
# CREATE TEMP REPO
# ============================================================
Head "Creating temp repo"

$script:BADGE_REPO = "gh-badges-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
$script:FULL = "$($script:USERNAME)/$($script:BADGE_REPO)"

gh api user/repos --method POST `
    -f name="$($script:BADGE_REPO)" `
    -f description="Temp badge repo - auto-deletes after running" `
    -F private=false -F has_issues=true | Out-Null

Log "Created: github.com/$($script:FULL)"
Start-Sleep -Seconds 4

$readmeB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("# $($script:BADGE_REPO)`nTemp badge automation repo."))
gh api "repos/$($script:FULL)/contents/README.md" --method PUT `
    -f message="init: initial commit" -f content="$readmeB64" | Out-Null

Ok "Repo ready."

# ============================================================
# QUICKDRAW
# ============================================================
Head "Quickdraw"

$issueNum = gh api "repos/$($script:FULL)/issues" --method POST `
    -f title="chore: setup" -f body="Closing immediately." --jq ".number"

gh api "repos/$($script:FULL)/issues/$issueNum" --method PATCH -f state=closed | Out-Null
Ok "Issue #$issueNum opened and closed instantly."

# ============================================================
# PULL SHARK + YOLO
# ============================================================
Head "Pull Shark + YOLO"

Log "PR 1 of 2..."
Merge-PR -Branch "feat/ci" -File "ci.md" -Title "feat: add CI notes"

Log "PR 2 of 2..."
Merge-PR -Branch "feat/docs" -File "NOTES.md" -Title "docs: add project notes"

Ok "2 PRs merged without review."

# ============================================================
# PAIR EXTRAORDINAIRE
# ============================================================
Head "Pair Extraordinaire"

Start-Sleep -Seconds 2

$db = Get-DefaultBranch
$sha = Get-HeadSha

gh api "repos/$($script:FULL)/git/refs" --method POST `
    -f ref="refs/heads/feat/collab" -f sha="$sha" | Out-Null

$collabB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("collaboration"))
$collabMsg = "feat: collaboration notes`n`nCo-authored-by: $COAUTHOR"

gh api "repos/$($script:FULL)/contents/COLLAB.md" --method PUT `
    -f message="$collabMsg" -f content="$collabB64" -f branch="feat/collab" | Out-Null

$pairPr = gh api "repos/$($script:FULL)/pulls" --method POST `
    -f title="feat: collaboration notes" `
    -f head="feat/collab" -f base="$db" --jq ".number"

gh api "repos/$($script:FULL)/pulls/$pairPr/merge" --method PUT `
    -f merge_method="squash" `
    -f commit_title="feat: collaboration notes" `
    -f commit_message="Co-authored-by: $COAUTHOR" | Out-Null

Ok "Pair Extraordinaire triggered. (Co-authored with @Chiragsd13)"

# ============================================================
# SUMMARY + CLEANUP
# ============================================================
Head "Done"

$mergedAfter = Get-MergedPRs

Write-Host ""
Write-Host "  Quickdraw            " -ForegroundColor Green -NoNewline; Write-Host "triggered"
Write-Host "  Pull Shark           " -ForegroundColor Green -NoNewline; Write-Host "triggered   ($mergedBefore -> $mergedAfter merged PRs)"
Write-Host "  YOLO                 " -ForegroundColor Green -NoNewline; Write-Host "triggered"
Write-Host "  Pair Extraordinaire  " -ForegroundColor Green -NoNewline; Write-Host "triggered   (with @Chiragsd13)"
Write-Host "  Galaxy Brain         " -ForegroundColor Yellow -NoNewline; Write-Host "manual   get 2 Discussion answers accepted"
Write-Host "  Public Sponsor       " -ForegroundColor Yellow -NoNewline; Write-Host "manual   sponsor any dev for min `$1/month"
Write-Host "  Starstruck           " -ForegroundColor Yellow -NoNewline; Write-Host "manual   get 16 stars on a personal repo"
Write-Host ""
Write-Host "  Badges appear within 24-48h at:" -ForegroundColor White
Write-Host "  https://github.com/$($script:USERNAME)?tab=achievements" -ForegroundColor Cyan
Write-Host ""

Cleanup
