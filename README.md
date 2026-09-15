# ⚡ PowerShell 7 Script Collection

A personal collection of PowerShell 7 scripts to automate repetitive tasks and manage files.

## 🚀 Setup on Windows

This collection works with **PowerShell 5.1 (built into Windows) or PowerShell 7+** — the installer below handles everything for you, including installing PowerShell 7 if you don't have it yet.

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/install.ps1 | iex
```

This single command will:

- Install PowerShell 7 if it isn't already on your system
- Set up this repo under `Documents\PowerShell` — if that folder already exists and isn't this repo, it's backed up as a whole first (see [Safe to re-run](#-safe-to-re-run--existing-files) below), nothing is deleted
- Add the `power-scripts` folder to your PATH so scripts can be run from anywhere
- Set your execution policy to `RemoteSigned` so the scripts are allowed to run

Restart your terminal afterward and you're ready to go 🎉

<details>
<summary>Prefer to see the manual steps instead?</summary>

1. **Install PowerShell 7** from the [official releases page](https://github.com/PowerShell/PowerShell/releases/latest) — download `PowerShell-<version>-win-x64.msi` and run it.
2. **Get the repo into `Documents\PowerShell`**:
   ```
   git clone https://github.com/astronaut-symphony/power-scripts.git "$HOME\Documents\PowerShell"
   ```
3. **Add the scripts folder to PATH**:
   ```
   [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$HOME\Documents\PowerShell\power-scripts", "User")
   ```
4. **Allow scripts to run**:
   ```
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```
5. **Enable the right-click context menu (optional)** — pick which scripts to register:
   ```
   .\power-scripts\setup-context-menu.ps1
   ```
</details>

### 🔁 Safe to re-run / existing files

`install.ps1` can be run again any time (e.g. to update) without losing your own work:

- If `Documents\PowerShell` is already this repo, it just runs `git pull` — any uncommitted local changes you made are stashed first (recoverable with `git stash pop`).
- If the folder exists but isn't this repo (e.g. it has your own `Microsoft.PowerShell_profile.ps1` or other scripts), the whole folder is renamed aside to `Documents\PowerShell_backup_<timestamp>` before a clean clone is done in its place. Nothing is deleted — copy anything you need back out of the backup folder afterward.

## 🔔 Update Checking

This repo tracks its own version in `power-scripts\version.txt`. Once installed, your profile checks for updates automatically (and every script reminds you at the end of a run):

- **Automatic:** every new terminal session checks once every 24 hours and only says something if an update is actually available — otherwise it stays silent.
- **Manual:** run `Test-PowerScriptsUpdate -Force` any time to check immediately, or run `PowerScripts.Update.ps1` by double-clicking / "Run with PowerShell".

If an update is available, you'll be asked whether to install it right then (Y/N) — or press `I` to ignore the prompt for a few days.

## 📂 Folder Structure

```
Documents\PowerShell\
├── power-scripts\          ← everything else: all scripts, install.ps1, version.txt (added to PATH)
│   ├── config\             ← local configuration, not tracked
│   └── .update-*-cache     ← update-check/snooze state, not tracked
├── Modules\                ← installed PowerShell modules (e.g. PSWritePDF), not tracked
├── Microsoft.PowerShell_profile.ps1
└── README.md
```

## 💡 Contribution

Want to improve or add new features?

- Fork this repo
- Create a branch: `git checkout -b feat/feature-name`
- Commit your changes
- Push and open a pull request

Let's build something helpful together!

## 📄 License

This repository is intended for personal use and experimentation. You're free to adapt it to your own workflows.