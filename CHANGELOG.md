# @openproject/helm-charts

## 3.0.1

### Patch Changes

- 0df7588: do not force read-only file system outside dev mode
- Publish helm charts on GitHub package registry: https://github.com/opf/helm-charts/pkgs/container/helm-charts%2Fopenproject

## 3.0.0

### Major Changes

- 0a1c9a9:
  - rename `securityContext` to `containerSecurityContext` in `values.yaml`
  - mount volumes for tmp directories to make containers work in accordance with best practices, that is with read-only file systems
  - use secure defaults for container security policy

## 2.7.0

### Minor Changes

- acf0e41: Allow OIDC attribute mapping in values
