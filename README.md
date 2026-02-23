# 🐳 Docker Desktop Update Manager

A Bash script for Ubuntu that checks, downloads, and installs Docker Desktop updates in a clean, sequential flow — with smart caching to avoid redundant downloads.

---

## Features

- **Sequential workflow** — check → download → install, each with its own confirmation prompt
- **Smart cache detection** — skips re-downloading if the same version `.deb` already exists in `/tmp`
- **Deferred install support** — you can download now and install later; the script will detect the cached file on the next run
- **Auto mode** — skip all prompts for use in CI/CD or automated pipelines
- **Dual version source** — falls back to GitHub API if Docker's download server doesn't return a version header
- **Safe error handling** — uses `set -euo pipefail`; cleans up incomplete downloads on failure

---

## Requirements

- Ubuntu (tested on 20.04+)
- `curl`
- `dpkg`
- `sudo` privileges (for `apt-get install`)

---

## Usage

```bash
# Make the script executable (first time only)
chmod +x docker-desktop-update.sh

# Run interactively (recommended)
./docker-desktop-update.sh

# Run in auto mode — skips all prompts
./docker-desktop-update.sh --auto
```

---

## Workflow

```
1. Check for Update
   └─ Compares installed version (via dpkg) vs. latest available version
   └─ Exits early if already up to date

2. Download
   └─ Checks /tmp for a previously downloaded .deb for the same version
       ├─ Found  → skips download, proceeds directly to install prompt
       └─ Not found → prompts to download, then fetches from Docker's servers

3. Install
   └─ Prompts to install the downloaded .deb via apt-get
       ├─ Confirmed → installs and cleans up the .deb file
       └─ Skipped   → keeps the .deb in /tmp for later; prints manual install command
```

---

## Example Output

```
[INFO]  Checking installed Docker Desktop version...
[INFO]  Current version: 4.28.0
[INFO]  Fetching latest version from Docker...
[INFO]  Latest version: 4.30.0
[INFO]  Update available: 4.28.0 → 4.30.0
Download Docker Desktop 4.30.0? (y/N): y
[INFO]  Downloading Docker Desktop 4.30.0 to /tmp/docker-desktop-4.30.0.deb...
######################################### 100.0%
[OK]    Download complete: /tmp/docker-desktop-4.30.0.deb
Install Docker Desktop 4.30.0 now? (y/N): y
[INFO]  Installing Docker Desktop 4.30.0...
[INFO]  Cleaning up downloaded file...
[OK]    Docker Desktop updated to 4.30.0
[INFO]  Restart Docker Desktop to apply changes:
[INFO]    systemctl --user restart docker-desktop
```

---

## Cache Behavior

The downloaded `.deb` is saved as:

```
/tmp/docker-desktop-<version>.deb
```

This means:
- If you downloaded but didn't install, re-running the script will detect the file and **go straight to the install prompt** — no re-download needed.
- If a newer version is available, the old cached file won't match and a fresh download will be triggered.

---

## Flags

| Flag     | Description                          |
|----------|--------------------------------------|
| `--auto` | Skip all confirmation prompts (yes to all) |

---

## Error Handling

| Scenario                              | Behavior                                                  |
|---------------------------------------|-----------------------------------------------------------|
| Latest version cannot be determined   | Exits with error after both sources (Docker + GitHub) fail |
| Download fails mid-way                | Incomplete `.deb` is deleted; error is reported           |
| Docker Desktop not installed          | Warns and continues (useful for fresh installs)           |

---

## Notes

- After installing, **restart Docker Desktop** to apply changes:
  ```bash
  systemctl --user restart docker-desktop
  ```
- The script does **not** require Docker Desktop to be stopped before updating — `apt-get` handles this.
- To manually install a cached `.deb`:
  ```bash
  sudo apt-get install -y /tmp/docker-desktop-<version>.deb
  ```
