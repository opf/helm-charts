---
"@openproject/helm-charts": minor
---

Fix Ruby pods crashing on CSI drivers that mount tmp volumes world-writable without the sticky bit. A non-root init container now creates a sticky-bit /tmp/ruby directory and TMPDIR is pointed at it. Can be disabled with openproject.tmpVolumesPermissionFix=false.
