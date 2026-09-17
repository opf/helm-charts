---
"openproject": minor
---

Make the bundled RustFS instance more configurable: add `rustfs.bucketInitJob.resources` and `rustfs.bucketInitJob.annotations` for the bucket init job, and wire the global `affinity` and `podAnnotations` values into the RustFS pod template (and `affinity` into the bucket init job) so they can be scheduled and annotated like the web/worker pods.

**Breaking:** rename `rustfs.s3Ingress` to `rustfs.ingress` for consistency with the top-level OpenProject `ingress` config. Update your values accordingly, e.g. `rustfs.ingress.host` instead of `rustfs.s3Ingress.host`.
