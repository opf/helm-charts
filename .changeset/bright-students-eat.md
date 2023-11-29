---
"@fake-scope/fake-pkg": major
---

* rename `securityContext` to `containerSecurityContext` in `values.yaml`
* mount volumes for tmp directories to make containers work in accordance with best practices, that is with read-only file systems
* use secure defaults for container security policy
