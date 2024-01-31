# @openproject/helm-charts

## 4.5.0

### Minor Changes

- b224135: Allow sealed secrets for OIDC secrets

## 4.4.0

### Minor Changes

- 08a7935: do not require a postgresql password anymore, allowing for automatically genererated credentials by default

## 4.3.1

### Patch Changes

- c9585aa: Add image PullSecrets to seeder job if configured

## 4.3.0

### Minor Changes

- 8e9c8e1: Feature: OIDC client id secret and docs
- 1f2594c: Add existingSecret for OIDC

## 4.2.1

### Patch Changes

- 8456845: Allow seting existing secret for s3 id and key

## 4.2.0

### Minor Changes

- ab8b83d: Fix tmp volume mounts not being consistent

## 4.1.4

### Patch Changes

- b3f06d1: Fix templating error when empty s3 existingSecret name is given
- 87f9dc4: Fix S3 secret lookup

  There were two problems:

  1. The namespace was hardcoded
  2. The whitespace trimming was breaking the yaml

  Now the lookup will be based on the namespace where the
  release is being deployed, and the whitespace trimming
  has been fixed.

- aa80a44: Correct attribute mapping environment name for OIDC
- e63389c: Allow controlling whether tmp volumes are used or not

## 4.1.3

### Patch Changes

- 7791166: fix pvc annotations

## 4.1.2

### Patch Changes

- a5b1573: Fixed extraEnvVarsSecret parameter in \_helpers.tpl

## 4.1.1

### Patch Changes

- ecd1778: Add artifacthub.io annotations

## 4.1.0

### Minor Changes

- aa7e492: Added OIDC provider displayName parameter

## 4.0.1

### Patch Changes

- 7511d98: Fix whitespace generation in s3 secret

## 4.0.0

### Major Changes

- 5f4bce6: Improve secret management.

  Add support for `existingSecret` for `postgresql` authentication.
  Move `s3.accessKeyId` and `s3.secretAccessKey` to `s3.auth.` and add an `existingSecret` option for S3.

### Patch Changes

- 8623b11: Add artifacthub-repo verification and badge

## 3.0.2

### Patch Changes

- 0df7588: do not force read-only file system outside dev mode

## 3.0.1

### Patch Changes

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
