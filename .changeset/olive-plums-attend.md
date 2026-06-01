---
"@openproject/helm-charts": patch
---

Make `openproject.useTmpVolumes` fall back to `containerSecurityContext.readOnlyRootFilesystem` rather than `not develop`.
