function prompt {
    # ANSI escape codes for colors
    $esc = [char]27
    $resetColor = "${esc}[0m"
    $blue = "${esc}[1;34m"
    $brightPink = "${esc}[1;95m"
    $yellow = "${esc}[1;33m"
    $green = "${esc}[1;32m"
    $greenBright = "${esc}[1;92m"
    $red = "${esc}[1;31m"
    $cyan = "${esc}[1;36m"
    $magenta = "${esc}[1;35m"

    # Git symbols (Powerlevel style)
    $gitSymbol = [char]0xe0a0  # 
    $gitUntrackedSymbol = '?'
    $gitModifiedSymbol = '!'
    $gitDeletedSymbol  = 'x'
    $gitStagedSymbol   = '+'
    $gitPushSymbol     = '↑'
    $gitPullSymbol     = '↓'

    # Get current path
    $fullPath = $PWD.Path
    $maxLength = 70
    $shortenedPath = if ($fullPath.Length -gt $maxLength) {
        " ...$($fullPath.Substring($fullPath.Length - $maxLength + 4))"
    } else {
        $fullPath
    }

    # Initialize Git info
    $gitBranch = ''
    $gitDetails = ''

    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            $status = git status --porcelain 2>$null

            $untracked = ($status | Select-String '^\?\?' -AllMatches).Matches.Count
            $modified = ($status | Select-String '^ M' -AllMatches).Matches.Count
            $deleted  = ($status | Select-String '^ D' -AllMatches).Matches.Count
            $staged   = ($status | Select-String '^[A-Z]' -AllMatches).Matches.Count

            try {
                $ahead  = git rev-list --count "HEAD@{u}..HEAD" 2>$null
                $behind = git rev-list --count "HEAD..HEAD@{u}" 2>$null
            } catch {
                $ahead = 0; $behind = 0
            }

            if ($staged   -gt 0) { $gitDetails += " $greenBright$gitStagedSymbol$staged$resetColor" }
            if ($modified -gt 0) { $gitDetails += " $yellow$gitModifiedSymbol$modified$resetColor" }
            if ($untracked -gt 0){ $gitDetails += " $cyan$gitUntrackedSymbol$untracked$resetColor" }
            if ($deleted  -gt 0) { $gitDetails += " $red$gitDeletedSymbol$deleted$resetColor" }
            if ($ahead    -gt 0) { $gitDetails += " $blue$gitPushSymbol$ahead$resetColor" }
            if ($behind   -gt 0){ $gitDetails += " $blue$gitPullSymbol$behind$resetColor" }

            $gitBranch = " $brightPink$gitSymbol $branch$resetColor$gitDetails"
        }
    } catch {}

    "`n$blue$shortenedPath$gitBranch$resetColor`n$cyan> $resetColor"
}

# === Update check for power-scripts ===
. (Join-Path $PSScriptRoot 'power-scripts\PowerScripts.Update.ps1')
Test-PowerScriptsUpdate -Silent
