---
"openproject": patch
---

The default worker now uses the top-level `resources` unless `workers.default.resources` is set. Before, `workers.default.resources` repeated the chart defaults, so changing `resources` (e.g. `--set resources.limits.cpu=2`) never reached the default worker. If you set `workers.default.resources`, set the whole block: missing keys are no longer filled in from the chart defaults.
