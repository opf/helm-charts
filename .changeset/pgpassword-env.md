---
"openproject": patch
---

Set `PGPASSWORD` alongside `OPENPROJECT_DB_PASSWORD` on all OpenProject containers. `DATABASE_URL` carries no password, so the `psql` probe in `docker/prod/migrate` could not authenticate.
