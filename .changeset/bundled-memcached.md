---
"openproject": major
---

Replace the Bitnami Memcached dependency with a single in-chart Deployment using the official `memcached:1.6.45-alpine` image. The cache uses a new internal Service and starts empty on upgrade. External cache connection settings remain supported. Review the README's Memcached values mapping before upgrading; Bitnami-specific authentication, persistence, metrics, and replica settings are no longer supported. Configured Bitnami SASL authentication blocks the upgrade until an external authenticated cache is selected.
