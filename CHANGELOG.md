# @openproject/helm-charts

## 3.0.0

### Major Changes

- 0a1c9a9: \* rename `securityContext` to `containerSecurityContext` in `values.yaml`
  - mount volumes for tmp directories to make containers work in accordance with best practices, that is with read-only file systems
  - use secure defaults for container security policy

## 2.7.0

### Minor Changes

- acf0e41: Allow OIDC attribute mapping in values
