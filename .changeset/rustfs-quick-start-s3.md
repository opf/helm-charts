---
"openproject": minor
---

Add `rustfs.bundled` option to deploy a minimal, single-node [RustFS](https://rustfs.com) instance and automatically configure it as S3-compatible attachment storage. This is a hand-rolled single-container Deployment maintained directly by this chart, not a dependency on the official RustFS Helm chart, keeping the chart's own dependency footprint (and CI/build-time exposure to third-party chart repositories) unchanged. Intended as a quick way to get S3 storage working out of the box; for production, install the official RustFS Helm chart (https://charts.rustfs.com) separately instead.
