# php2shell (real) — isolated reproduction

This post-CTF research environment models the reported two Nginx/PHP-FPM
targets and one Apache prefork/mod_php target. It contains no challenge token or
instance lifecycle. Everything runs in Docker on an internal network, and the
three HTTP ports bind only to host loopback.

| Profile | Endpoint | Stack |
| --- | --- | --- |
| `fpm` | `127.0.0.1:18081`, `:18082` | Nginx 1.30.6 + PHP-FPM + WordPress |
| `apache` | `127.0.0.1:18083` | Apache prefork + mod_php + WordPress |
| `traffic` | none | Optional random requests to running targets |

The Apache port passes through an Nginx `stream` (Layer 4) gateway. No HTTP
reverse proxy terminates or splits the client connection: each client TCP
connection maps to one backend TCP connection and retains Apache prefork-worker
affinity. The gateway is required because Docker does not publish ports directly
from an `internal: true` network; it bridges the isolated lab to loopback only.

## Start a reproducible target set

The default version mix is `5.6.35 / 7.4.24 / 8.4.26`; Apache defaults to four
workers and background traffic is off.

If upgrading from the previous gateway layout, first run
`docker compose down --remove-orphans` to stop its old containers. This keeps
the named WordPress/database volumes; use `--volumes` only when a reset is
intended.

```sh
cd challenge
docker compose --profile apache --profile fpm up -d --build
./scripts/verify.sh
```

Start only the Apache research target:

```sh
docker compose --profile apache up -d --build
```

Add interfering traffic explicitly:

```sh
docker compose --profile apache --profile fpm --profile traffic up -d
```

`traffic` deliberately has no hard dependency on the target profiles. Missing
origins are ignored. Set `TRAFFIC_ORIGINS=http://wp-apache` when running only
Apache if quieter logs are desired.

## Version matrix

The checked-in matrix is the cross product of:

- FPM A: PHP `5.6.35` or `5.6.39`
- FPM B: PHP `7.1.4` or `7.4.24`
- Apache: PHP `8.4.26` or `8.5.11`

`5.6.35`, `7.1.4`, and `7.4.24` were observed live according to the handoff.
`8.4.26` and `8.5.11` are its calibrated Apache lab builds. The handoff has
only one exact 5.6 patch version, so `5.6.39` is the second choice retained from
the earlier verified reconstruction; it is not claimed as a recovered live
version.

There are eight files in `presets/versions/`. Select one explicitly:

```sh
docker compose \
  --env-file presets/versions/02-5635-714-8511.env \
  --env-file presets/workers/small-pool.env \
  --profile apache --profile fpm up -d --build
```

Each image is built from an exact `php:<patch>-fpm` or `php:<patch>-apache`
base plus the listed WordPress release. This avoids floating `php8.x` image
tags silently changing the PHP patch version. Targets default to `linux/amd64`
because allocator layout and symbol offsets are architecture-specific.

Changing version presets requires fresh WordPress/database volumes:

```sh
docker compose --profile apache --profile fpm down --volumes --remove-orphans
```

## Apache worker presets

| Preset | Workers | Intended use |
| --- | ---: | --- |
| `deterministic.env` | 1 | Heap primitives, leak and offset work |
| `small-pool.env` | 4 | Default affinity/retry testing |
| `realistic.env` | 150 | Late-stage live-pool and pinning validation |

Example:

```sh
docker compose \
  --env-file presets/versions/03-5635-7424-8426.env \
  --env-file presets/workers/deterministic.env \
  --profile apache up -d --build
```

The 150-worker preset reserves 10 GiB and 256 PIDs. Measure actual RSS for the
chosen build and adjust before using it. It is intentionally not the default.

## Isolation and caveats

- Targets have only an `internal: true` Docker network and cannot make ordinary
  outbound connections.
- Published ports bind to `127.0.0.1`, never `0.0.0.0`.
- Read-only, unprivileged TCP gateways bridge loopback to the internal network;
  they have no dynamic proxy route.
- HTTP application healthchecks and background traffic are off by default so
  deterministic heap experiments are not perturbed.
- Database healthchecks remain because they do not execute PHP requests.
- PHP 8.3 and older are useful controls for the general primitive, but the
  handoff says the documented Apache `send_cookie` in-band chain needs PHP
  8.4+; this matrix therefore assigns 8.4/8.5 to the Apache slot.
- Exact offsets remain build-specific. Keep the selected preset in experiment
  notes and do not expose this deliberately vulnerable lab publicly.

Stop the lab while preserving data with `docker compose down`, or add
`--volumes` for a complete reset. See [RESEARCH.md](RESEARCH.md) and the root
handoff for evidence and remaining fidelity limits.
