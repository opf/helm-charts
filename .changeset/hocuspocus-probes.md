---
"openproject": minor
---

Add livenessProbe and readinessProbe to the hocuspocus deployment. They can be disabled via `hocuspocus.probes.enabled`, and their settings can be overridden per probe via `hocuspocus.probes.liveness` and `hocuspocus.probes.readiness` (defaulting to the global `probes` settings).
