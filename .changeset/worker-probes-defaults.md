---
"openproject": patch
---

Fix rendering of additional `workers` entries that don't configure `probes` (nil pointer evaluating `.probes.enabled`). Worker probe defaults now live in `worker.probes` and apply to all workers, with per-worker overrides under `workers.<name>.probes`.
