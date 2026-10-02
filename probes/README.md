# Probes

Scripts written on 21 and 22 April 2026 while this image was being made to work. Each one asks a single question of an image. They are kept so that the decisions in [`docs/decisions/`](../docs/decisions/) can be checked again.

## Read this first

- **No probe saves its output, and the output from April 2026 was not kept.** This index says what each probe asks. It does not say what the probe answered, except where a project file states the conclusion.
- Every script was written as `tmp_<name>` in a staging folder outside this repository and copied here unchanged on 2026-10-02. Only the `tmp_` prefix was dropped.
- All of them need Docker. Those under "built image" need `devbrewery/photoframe-immich:latest` built locally (`./build.sh`). Those under "upstream" pull `ghcr.io/immich-app/immich-server` for `linux/amd64`.
- The three container tests in `bind-host/` start a container on host port 22830 and remove it afterwards. Everything else only runs a throwaway container or downloads a tarball to a temp folder.

## `libvips-sharp/` — behind decision [0001](../docs/decisions/0001-libvips-from-npm-and-stock-sharp.md)

In the order they were written.

| Probe | Looks at | Question |
|---|---|---|
| `export_test.sh` | upstream v2.7.5 | Are the four libraries (`libvips-cpp`, `libvips`, `libheif`, `libjxl`) also empty when pulled out with `docker export` instead of `docker cp`? |
| `inspect_hardlinks.sh` | upstream v2.7.5 | In the raw export stream, are those files hard links whose content sits under another path? |
| `run_inspect.sh` | upstream v2.7.5 | Inside a running upstream container, what are the sizes, inodes and file types of the libvips, libheif and libjxl files? |
| `find_real_libvips.sh` | upstream v2.7.5 | Is there a non-empty `libvips*` file anywhere on the upstream filesystem? Where is the sharp binary, and what does the linker cache hold? |
| `test_upstream.sh` | upstream v2.7.5 | Does `sharp` load at all in the untouched upstream image? |
| `check_tags.sh` | upstream `release` and `v1.140.0` | Do other upstream tags have the same libvips sizes, and does `sharp` load there? |
| `check_baseserverprod.sh` | `base-server-prod` | Does Immich's base image have a working libvips, and which dated tags of it exist? |
| `check_sharplibvips.sh` | npm registry | Which `@img/sharp-libvips-*` version does `sharp` 0.34.5 ask for, and what is in the package? |
| `check_libvips_deps.sh` | npm package, in `node:24-trixie-slim` | What shared libraries does `libvips-cpp.so.8.17.3` from the npm package need? |
| `verify_sharp.sh` | built image | After the fix: are the libvips files in place, and does `sharp` load from `/opt/immich-server`? |
| `inspect_pkg.sh` | npm package | What exactly is in `@img/sharp-libvips-linux-x64` 1.2.4? |
| `verify_sharp2.sh` | built image | If `sharp` fails to load: what is the full error, and what does `ldd` say about the sharp binary? |
| `check_stock_sharp.sh` | npm package, in `node:24-trixie-slim` | What does the stock prebuilt `sharp-linux-x64.node` 0.34.5 link against? |

## `bind-host/` — behind decision [0002](../docs/decisions/0002-bind-host-0.0.0.0.md)

In the order they were written, all on 22 April 2026.

| Probe | Looks at | Question |
|---|---|---|
| `find_listen.sh` | built image | What `IMMICH`/`HOST` variables are set, and where does the server's built code call `listen`? |
| `grep_listen.sh` | built image | What does the `.listen(` call in `dist/app.common.js` look like, with its surrounding lines? |
| `grep_host.sh` | built image | Where is the host assigned in `dist/app.common.js` (lines 30 to 70, the bootstrap function)? |
| `grep_host2.sh` | built image | Who calls `bootstrapCommon`, and where else is `IMMICH_HOST` read? |
| `manual_test.sh` | running container | Is the server reachable inside the container over IPv4, inside over IPv6, and from the host through the mapped port? |
| `manual_test2.sh` | running container | After 90 seconds: what do the logs, the listening sockets and the process tree show? |
| `check_host.sh` | built image | How does `dist/repositories/config.repository.js` (lines 125 to 150) read `IMMICH_HOST`? |
| `test_bind.sh` | running container | What is Docker's port mapping, does the host reach the server, and what is listening according to `/proc/net/tcp`? |
| `find_ping.sh` | built image | Which ping route do the server's controllers define? |

`test_bind.sh` reads listening sockets by decoding `/proc/net/tcp` and `/proc/net/tcp6` with `awk`. That works in an image that has neither `ss` nor `netstat`.

## Open items

These were open when the probes were filed here. None has been resolved.

1. **Two probes have no recorded answer anywhere:** `check_baseserverprod.sh` and `check_tags.sh`. No project file states what they found.
2. **The ping route is not settled.** `Dockerfile` (HEALTHCHECK) and `docker-compose.yml` use `/api/server-info/ping`. `test.sh` uses `/api/server/ping`. `find_ping.sh` was the last probe written and looks for exactly this; what it found is not recorded.
3. **Nothing in `test.sh` checks that `sharp` loads.** `verify_sharp.sh` and `verify_sharp2.sh` are the only place that check exists, and it is the thing decision 0001 is for.
