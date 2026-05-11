# Contributing

PRs and issues welcome. By contributing you agree to license your changes under GPL-2.0.

## Issues

Please include:
- RG35XXH variant (front-port arrangement, panel rev if known)
- microSD card (size, brand)
- `dmesg | tail -100` from a failed boot if possible (extract via `/boot/logs/` — dump-boot-logs.service runs at multi-user.target)
- Build commit hash (`git rev-parse --short HEAD`)

## PRs

- Keep stages idempotent
- If you add a workaround, document it in `docs/PITFALLS.md`
- Test that `./build.sh all` still completes on a clean clone
