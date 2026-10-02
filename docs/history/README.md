# History

Files kept from April 2026 because the decisions in [`docs/decisions/`](../decisions/) refer to them. They are copies of what was on disk then. The one change: in three files, local machine paths were replaced with placeholders (see "Placeholders" below). Nothing here is used by the build.

Each was written as `tmp_<something>` in a staging folder outside this repository and copied here on 2026-10-02.

| File | Was | What it is |
|---|---|---|
| `Dockerfile.before-libvips-fix` | `tmp_Dockerfile_before` | The build recipe on 21 April 2026, before decision 0001. Upstream's `/usr/local/lib` is copied in and its system libraries come from apt. `IMMICH_HOST` is not set. |
| `Dockerfile.2026-04-22` | `tmp_Dockerfile` | The build recipe on 22 April 2026, 10:46, after decision 0001. Today's `Dockerfile` differs from it only in the machine-learning and memory settings. |
| `build-failure-2026-04-20.txt` | `tmp_immich_build.log` | Output of the failed local multi-architecture build behind decision 0003. Renamed from `.log` because this repository ignores `*.log`. It contains terminal colour codes. |
| `install-staged-files.sh` | `tmp_install.sh` | The one-off script that copied five staged files into this project (`scripts/init.sh`, `scripts/backup.sh`, `test.sh`, and the `postgres` and `immich-server` run scripts) and deleted the staged copies. Kept as a record of how those files arrived. **Do not run it:** its sources no longer exist. |
| `docker-state-2026-04-21/dockerd-log-tail.txt` | `tmp_dockerd_diag.txt` | A 60-line tail of Docker Desktop's daemon log, captured on 21 April 2026. Its entries are from 9 December 2025. Ends with a note that Docker's `wsl\data` folder was missing. |
| `docker-state-2026-04-21/vhd-sizes.txt` | `tmp_vhd_sizes.txt` | Sizes of Docker's data disk (137.53 GB) and two WSL disks on 21 April 2026. |
| `docker-state-2026-04-21/docker-df.txt` | `tmp_docker_df.txt` | An empty file. Whatever was meant to be captured in it was not. Kept because it shows what was attempted that morning. |

## Why the Docker state files are here

They were captured on 21 April 2026 between 11:50 and 12:14, the day after the failed build and before the libvips investigation started that afternoon. No file says why. They are kept as context for that day and support no decision.

## Placeholders

`install-staged-files.sh` and the two non-empty files under `docker-state-2026-04-21/` originally contained local machine paths. In the copies committed here those are replaced:

| Placeholder | Stands for |
|---|---|
| `LOCAL_USER` | the account name, in a Windows user folder or a Linux home folder |
| `LOCAL_DRIVE` | the drive letter of the staging folder, as mounted in WSL |
| `LOCAL_STAGING_DIR` | the staging folder outside this repository where the files were written |

Nothing else in those files was changed. The unmodified files and the real values are kept in `.config/`, which this repository ignores.
