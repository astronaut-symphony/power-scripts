# PowerShell 7 Script Collection

A personal collection of PowerShell 7 scripts to automate repetitive tasks and manage files.

## Install, update and uninstall

Everything is **per-user — no administrator rights or password needed** — and works from **Windows PowerShell 5.1 (built into Windows) or PowerShell 7+**. Open PowerShell and run:

**Install** (and **update** — it's the same command):

```powershell
irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/install.ps1 | iex
```

**Uninstall:**

```powershell
irm https://raw.githubusercontent.com/astronaut-symphony/power-scripts/main/power-scripts/uninstall.ps1 | iex
```

### What the installer does

1. Downloads the **latest GitHub release** (no git needed). If the download fails, nothing is changed.
2. Installs **PowerShell 7** for your user with `winget` if it's missing (portable ZIP fallback if winget isn't available).
3. Puts the scripts in `Documents\PowerShell\power-scripts`. When updating, the previous version is kept as `power-scripts_backup`, so you can go back one step.
4. If you already have a PowerShell profile, it **asks** before using the bundled one (yours is saved as a `.bak`). It never overwrites your profile silently.
5. Adds `power-scripts` to your user `PATH` and sets the execution policy to `RemoteSigned` (current user only).
6. Offers to set up the right-click menu — or, on an update, refreshes the entries you already have.

Restart your terminal afterward and you're ready to go. Re-running the installer is always safe.

> If `Documents\PowerShell` is a git checkout (a developer's working copy), the installer and the update prompt leave it alone — update that with `git pull`.

### Right-click menu

Right-click **empty space inside a folder** → **Power Script**, then pick:

| Menu item | What it does |
|---|---|
| Check Duplicates | `duplicate-file-check.ps1` |
| Get File List | `get-file-list.ps1` |
| Split PDF | `split-pdf.ps1` |
| Excel to PDF | `excel-to-pdf.ps1` — pick one or many Excel files, then a folder; each workbook becomes one PDF with all its sheets (needs Microsoft Excel) |

To choose which entries are shown, run `setup-context-menu.ps1` and pick numbers to toggle them. All scripts can also be run directly from a terminal (e.g. `get-file-list.ps1 -WithExtension`; add `-Help` to see the options of a script).

### Updates

Updates come from **GitHub releases**. Every script reminds you at the end of a run (checked at most once every 24 hours; a new terminal also checks quietly) when a newer release exists. Answer `Y` to update right away, `N` to skip, or `I` to ignore the prompt for a few days. To check immediately, run `Test-PowerScriptsUpdate -Force`, or just run the install command again.

### Uninstall

The uninstaller removes `power-scripts` from your `PATH`, removes the right-click menu entries, deletes the `power-scripts` folder (after asking) and optionally resets the execution policy. PowerShell 7 and your profile are **not** removed.

## Folder Structure

```
Documents\PowerShell\
├── power-scripts\          ← all scripts, install.ps1, uninstall.ps1, version.txt (added to PATH)
│   ├── config\             ← local configuration, kept across updates
│   └── .update-*-cache     ← update-check/snooze state
├── power-scripts_backup\   ← previous version, created by an update
├── Modules\                ← installed PowerShell modules (e.g. PSWritePDF), not touched
└── Microsoft.PowerShell_profile.ps1
```

## For developers

Clone the repo (`git clone https://github.com/astronaut-symphony/power-scripts.git "$HOME\Documents\PowerShell"`) instead of using the installer, and update with `git pull`. The installer and the update prompt detect the `.git` folder and stay out of the way.

**Releasing a new version** (what users receive is the latest *release*, not `main`):

1. Put your changes on `main` and bump `power-scriptsersion.txt` (e.g. `1.0.3`).
2. Create a GitHub release with the matching tag (`v1.0.3`). Until then, nobody is offered the update.

Want to contribute? Fork this repo, create a branch (`git checkout -b feat/feature-name`), commit, push and open a pull request.

## License

This repository is intended for personal use and experimentation. You're free to adapt it to your own workflows.