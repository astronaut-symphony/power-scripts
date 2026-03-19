# ⚡ PowerShell 7 Script Collection

A personal collection of PowerShell 7 scripts to automate repetitive tasks, manage files, and process media.
<br/><br/><br/>

## 📁 Scripts Overview

| Script Name                 | Description |
|-----------------------------|-------------|
| `ytdlp`                     | Downloads videos/audio/subtitles from online sources via `yt-dlp` with simple options. |
| `ffmpeg`                    | Wraps common `ffmpeg` tasks like audio extraction, merging, format conversion, and tag editing. |
| `collect-files`             | Collects and copies files from nested directories based on a given list or filenames. |
| `duplicate-check`           | Detects duplicate files by filename (excluding extension) in current and subdirectories. |
| `get-file-list`             | Outputs a structured list of files grouped by their folder to `FileList.txt`. |
| `rename-files`              | Renames files based on a CSV-style list, with include/exclude folder filtering. |
| `clear-autocad-plot-suffix` | Recursively renames exported AutoCAD PDFs by removing suffixes like `-Layout1` or `-Model`. |
| `image2pdf`                 | Converts all images in a folder into individual PDFs using Microsoft Print to PDF. |
| `pwsh-context-menu`         | Quickly add or remove right-click context menu entries to open PowerShell 7 in any folder or folder background. |

<br/>

**Note:** You can run this script with `-Help` option to display all available options along with usage instructions and examples.
<br/><br/><br/>

## ⚙️ Setup on Windows

This script collection works best with **PowerShell 7+**. Follow these steps to get started:
<br/><br/>

### 1. Install PowerShell 7

If you're still using Windows PowerShell 5.1, it's strongly recommended to upgrade to PowerShell 7 for better performance and compatibility.

- Visit the official GitHub releases page [here](https://github.com/PowerShell/PowerShell/releases/latest).

- Scroll down to the "Assets" section.

- Download the appropriate installer for your system: `PowerShell-<version>-win-x64.msi`.
Example: `PowerShell-7.5.2-win-x64.msi`

- Open the .msi file to start the installation and follow the setup wizard.

Once installed, **open PowerShell 7** (you can find it as `PowerShell 7` in your Start Menu or run `pwsh` from any terminal).
<br/><br/>

### 2. Clone This Repository to Your PowerShell Folder

Inside your PowerShell 7 terminal, you can use either method below to set up the repository inside your PowerShell folder:

Without Git (using `curl`):

```powershell
curl -L -o "$env:TEMP\repo.zip" "https://github.com/astronaut-symphony/power-scripts/archive/refs/heads/main.zip"; Expand-Archive "$env:TEMP\repo.zip" "$env:TEMP\repo" -Force; Move-Item "$env:TEMP\repo\power-scripts-main\*" "$HOME\Documents\PowerShell\" -Force; Remove-Item "$env:TEMP\repo.zip","$env:TEMP\repo" -Recurse -Force
```
<br/>

Or, with Git (if installed):

```powershell
git clone https://github.com/astronaut-symphony/power-scripts.git "$HOME\Documents\PowerShell"
```

This will place the scripts directly under your `Documents\PowerShell\` folder.
<br/><br/>

### 3. Add Script Folder to PATH

To use your scripts globally (from any folder), run:

```powershell
[Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$HOME\Documents\PowerShell\Scripts", "User")
```

Then restart your terminal.
<br/><br/>

### 4. Allow Scripts to Run

If this is your first time running custom PowerShell scripts, you may need to allow it:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

When prompted, type `Y` to confirm.
<br/><br/>

### 5. Enable PowerShell 7 context menu (optional):

Open PowerShell 7 as Administrator, run: 
```powershell
pwsh-context-menu.ps1 -Enable
```

🎉 That’s it! You’re now ready to use the scripts to simplify your file handling and automation tasks.
<br/><br/><br/>

## 📦 External Tools

Some scripts rely on external tools stored in the `Library/` directory:

| Tool     | Path                            | GitHub / Source Link                                  |
|----------|----------------------------------|--------------------------------------------------------|
| `yt-dlp` | `Library/ytdlp/yt-dlp.exe`      | [github.com/yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp) |
| `ffmpeg` | `Library/ytdlp/ffmpeg.exe`      | [github.com/FFmpeg/FFmpeg](https://github.com/FFmpeg/FFmpeg) |

These tools are downloaded and maintained automatically if missing. They are excluded from Git tracking.
<br/><br/><br/>

## 💡 Contribution

Want to improve or add new features?

- Fork this repo
- Create a branch: `git checkout -b feat/feature-name`
- Commit your changes
- Push and open a pull request

Let's build something helpful together!
<br/><br/><br/>

## 📄 License

This repository is intended for personal use and experimentation. You’re free to adapt it to your own workflows.
<br/><br/><br/>
