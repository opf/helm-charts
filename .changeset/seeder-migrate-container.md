---
"openproject": patch
---

Run the database migration in its own `migrate` init container in the seeder job, ahead of the `seeder` container, instead of relying on `docker/prod/seeder` to run both steps implicitly.
