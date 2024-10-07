---
"@openproject/helm-charts": major
---

Unset the image tag so users have to specify it explicitly. The problem with using `14-stable` is that new releases will auto rollover
and break as the migration and seeding job is not being run. Upgrades between versions should be explicit.
