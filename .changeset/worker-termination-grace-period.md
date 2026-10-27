---
"openproject": minor
---

Add `worker.shutdownTimeout` (default `60`, overridable per worker via `workers.<name>.shutdownTimeout`) to set `OPENPROJECT_GOOD_JOB_SHUTDOWN_TIMEOUT`, and default worker `terminationGracePeriodSeconds` to `shutdownTimeout + 30` (overridable via `worker.terminationGracePeriodSeconds` or `workers.<name>.terminationGracePeriodSeconds`).
