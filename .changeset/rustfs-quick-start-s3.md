---
"openproject": minor
---

Add `rustfs.bundled` option to deploy a minimal, single-node [RustFS](https://rustfs.com) instance and automatically configure it as S3-compatible attachment storage. Intended as a quick way to get S3 storage working out of the box; for production, install the official RustFS Helm chart (https://charts.rustfs.com) separately instead, or use an external S3 service.
