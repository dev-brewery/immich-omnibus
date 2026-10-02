# 0003 — local builds are single-architecture; multi-architecture builds push

Date of the work: 20 to 22 April 2026. Written up: 2 October 2026, from the files that survive.

## What the build does

In `build.sh`:

- `./build.sh [version]` builds for the host's architecture only and loads the image into the local Docker (`--load`).
- `./build.sh --push [version]` builds `linux/amd64` and `linux/arm64` and pushes both to Docker Hub.
- `--skip-extract` reuses an existing `./ctx`.

## Why

[`docs/history/build-failure-2026-04-20.txt`](../history/build-failure-2026-04-20.txt) is the output of an earlier version of the script. It announced "Building for: linux/amd64,linux/arm64" and "Building locally (not pushing)", and stopped with:

```
ERROR: failed to build: docker exporter does not currently support exporting manifest lists
```

A multi-architecture result is a manifest list, and the local Docker image store could not take one. A local build therefore has to be a single architecture, and a build of both has to go to a registry.

**Inferred:** the split in `build.sh` is the answer to that failure. The log's wording does not match the current script, so it came from an earlier version, and no file says so in words.

## To check it again

```
./build.sh                # host architecture only, image appears in "docker images"
./build.sh --push v1.0.0  # both architectures, pushed
```

## Open

- `CLAUDE.md` still says `./build.sh` builds a "multi-platform image locally (amd64 + arm64)", and gives the push form as `./build.sh v1.0.0 --push`. The first is the behaviour that failed. The second works, since flags may come in any position.
- When this was written, the `build.sh` change it describes was in the working tree and not yet committed.
