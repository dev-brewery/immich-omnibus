# 0001 — libvips comes from npm, and sharp is the stock prebuilt binary

Date of the work: 21 and 22 April 2026. Written up: 2 October 2026, from the files that survive.

## What the build does

In `Dockerfile`:

- A `sharp-downloader` stage downloads two npm tarballs: `@img/sharp-libvips-<arch>` 1.2.4 and `@img/sharp-<arch>` 0.34.5.
- `libvips-cpp.so.8.17.3` from the first is installed into `/usr/local/lib`, with `libvips-cpp.so.42` and `libvips-cpp.so` linked to it.
- Immich's own `sharp-linux-<arch>.node` under `/opt/immich-server` is overwritten with the stock prebuilt one from the second tarball.
- The apt install no longer carries the image-decoder libraries that a system libvips would need.

## Why

Three statements, each taken from the comments in `Dockerfile` and `build.sh`:

1. **Cross-image `COPY` in BuildKit produced 0-byte files** under the docker-container driver and corrupted the content store on large copies. This is why `build.sh` extracts upstream content with `docker create` and `docker cp` into `./ctx/<arch>/` before the build. It predates the rest of this decision.
2. **Upstream v2.7.5 ships its own `/usr/local/lib/libvips*.so` files as 0 bytes.** The fault is in the upstream image, separately from point 1.
3. **Immich's custom-built sharp binary expects a split libvips / libvips-cpp layout** and segfaults when loaded against the combined libvips from npm. The stock prebuilt sharp expects the combined layout and works. It opens `libvips-cpp.so.8.17.3` by that exact name.

The npm libvips has only glibc runtime dependencies; the image decoders (heif, jxl, webp, png and others) are built into it. That is why the apt list shrank.

## What it replaced

[`docs/history/Dockerfile.before-libvips-fix`](../history/Dockerfile.before-libvips-fix) is the recipe before this decision. It copied upstream's `/usr/local/lib` in as `ctx/<arch>/immich-server/local-lib` and installed these packages for it:

`libexpat1 libexif12 libspng0 libwebp7 libwebpmux3 libwebpdemux2 librsvg2-2 libcairo2 liblcms2-2 libopenexr-3-1-30 libopenjp2-7 libhwy1t64 libde265-0 liblqr-1-0 libltdl7 libgsf-1-114 libaom3 libmimalloc3 libio-compress-brotli-perl`

If upstream ever ships working libraries again, that file is the starting point for going back.

## Evidence

The thirteen probes in [`probes/libvips-sharp/`](../../probes/libvips-sharp/), indexed in [`probes/README.md`](../../probes/README.md). In outline:

- Five look at upstream v2.7.5 from different angles to establish that the empty files are really empty and are not an artefact of how they were extracted (`export_test`, `inspect_hardlinks`, `run_inspect`, `find_real_libvips`, `test_upstream`).
- Two look for a working libvips elsewhere upstream (`check_tags`, `check_baseserverprod`).
- Four examine the npm packages that became the fix (`check_sharplibvips`, `check_libvips_deps`, `inspect_pkg`, `check_stock_sharp`).
- Two check the result in the built image (`verify_sharp`, `verify_sharp2`).

**The output of these probes was not kept.** The three statements under "Why" are what the build files say. They have not been re-run for this write-up.

## To check it again

```
./build.sh
./probes/libvips-sharp/verify_sharp.sh      # expect "SHARP OK" and a versions object
./probes/libvips-sharp/run_inspect.sh       # shows the upstream file sizes for v2.7.5
```

When `IMMICH_VERSION` is bumped, run `run_inspect.sh` and `test_upstream.sh` with the new tag first. If upstream's libraries are no longer empty, this decision should be looked at again.

## Open

- Whether other upstream tags and Immich's base image have the same defect was probed (`check_tags.sh`, `check_baseserverprod.sh`) and the answer was not recorded.
- `test.sh` does not check that `sharp` loads.
- `CLAUDE.md` still describes the earlier design: its stage list names `immich-server` and `immich-ml` as build stages, and its copy table lists `/usr/local/lib (libvips/libheif/…)` as copied from upstream.
- When this was written, the `Dockerfile` and `build.sh` changes it describes were in the working tree and not yet committed.
