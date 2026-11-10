---
"openproject": major
---

Replace the bundled Bitnami PostgreSQL dependency with a single PostgreSQL 18 instance using `pgvector/pgvector`. New databases enable vector. Existing Bitnami databases require dump/restore into a separate PVC before upgrading; see the [migration and rollback guide](https://github.com/opf/helm-charts/blob/main/charts/openproject/POSTGRESQL.md). PostgreSQL 17 can be selected explicitly for new clusters. External databases remain supported. Bundled replication, failover, and Bitnami-specific values are not supported.
