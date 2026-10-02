# 0002 — the server binds to 0.0.0.0

Date of the work: 22 April 2026. Written up: 2 October 2026, from the files that survive.

## What the build does

- `Dockerfile` sets `IMMICH_HOST=0.0.0.0` in the image environment.
- `docker-compose.yml` sets `IMMICH_HOST: "0.0.0.0"` for the server.
- `s6/services/immich-ml/run` exports `IMMICH_HOST="127.0.0.1"` before starting the machine-learning service. Read together, the intent is that the server is reachable from outside the container and the ML service only from inside. That reading is an inference from the two settings; no file says it.

## Why

No file states the reason in words. What the files show:

- [`docs/history/Dockerfile.before-libvips-fix`](../history/Dockerfile.before-libvips-fix) (21 April) does not set `IMMICH_HOST`.
- [`docs/history/Dockerfile.2026-04-22`](../history/Dockerfile.2026-04-22) (22 April, 10:46) does.
- Nine probes written the same day between 11:26 and 16:18 examine how the server chooses its listen address and whether it can be reached from inside the container over IPv4, inside over IPv6, and from the host through a mapped port.

**Inferred, not recorded:** without the setting, the server listened on an address that Docker's port mapping could not reach, so the container looked healthy from inside and dead from the host. The comparison in `manual_test.sh` (IPv4 inside, IPv6 inside, host) is the test that would show exactly that.

**Not known:** the setting was already in the `Dockerfile` snapshot at 10:46, before the first probe at 11:26. Whether the probes were confirming a fix already made, or chasing a problem that remained after it, cannot be told from the files. Their output was not kept.

## Evidence

The nine probes in [`probes/bind-host/`](../../probes/bind-host/), indexed in [`probes/README.md`](../../probes/README.md). They name the places in the server's built code where the address is handled:

- `dist/app.common.js`: the bootstrap function (`bootstrapCommon`) and its `.listen(` call.
- `dist/repositories/config.repository.js`, around lines 125 to 150: where `IMMICH_HOST` is read.

Those line numbers belong to Immich v2.7.5 and will move with other versions.

## To check it again

```
./build.sh
./probes/bind-host/test_bind.sh     # port mapping, a ping from the host, and the listening sockets
./probes/bind-host/manual_test.sh   # the same ping three ways: IPv4 inside, IPv6 inside, from the host
```

A server bound correctly answers all three requests in `manual_test.sh`, and `test_bind.sh` lists a listener on `0.0.0.0` (shown as `00000000`) port 2283.

## Open

- **The ping route.** These probes, the `Dockerfile` HEALTHCHECK and `docker-compose.yml` all request `/api/server-info/ping`. `test.sh` requests `/api/server/ping`. `find_ping.sh`, the last probe written, searches the server's controllers for the route; its result was not recorded. If `/api/server-info/ping` does not exist in v2.7.5, the container health check fails even when the server is up. Not verified.
- When this was written, the `Dockerfile` change it describes was in the working tree and not yet committed.
