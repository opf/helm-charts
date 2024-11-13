# @openproject/helm-charts

## 9.0.0

### Major Changes

- 57d032f: Upgrade OpenProject to 15.0

## 8.3.2

### Patch Changes

- 470b8ed: Bump version to 14.6.3

## 8.3.1

### Patch Changes

- a636fc2: Fix indent when outputting host without ingress
- b3d31ef: apply secret reset fix from other envs in core where it was missing

## 8.3.0

### Minor Changes

- 9a71b28: Allow unsetting the host name env

## 8.2.0

### Minor Changes

- b82aaf4: Allow setting options for the deployment strategy:

  You can now provide custom options to the strategy, for example:

  **values.yaml**:

  ```yaml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 30%
      maxUnavailable: 30%
  ```

## 8.1.3

### Patch Changes

- 284e340: Fix background queue name not being picked up

## 8.1.2

### Patch Changes

- 79680db: Upgrade OpenProject core version to 14.6.2 (patch update)

## 8.1.1

### Patch Changes

- a17c6a8: Upgrade OpenProject core version to 14.6.1 (patch update)

## 8.1.0

### Minor Changes

- 1646954: Bump OpenProject version to 14.6.0

## 8.0.0

### Major Changes

- b460db3: Rename initdb -> dbInit to be consistent

### Minor Changes

- b460db3: Fix resource limits/requests for worker and web deployment
- 0fa8a05: add resource limit for init-container - for worker-deployment

## 7.2.0

### Minor Changes

- 3ff3f95: add resource limit for init-container

## 7.1.0

### Minor Changes

- cc06e6f: add resource request and limit for seederJob container

## 7.0.0

### Major Changes

- 7bb899a: - Rename persistance.tmpStorageClassName to openproject.tmpVolumesStorageClassName for consistency with other options
  - Allow setting annotations for /tmp and /app/tmp volumes
  - Allow setting labels for /tmp and /app/tmp volumes

### Minor Changes

- 16db2be: Allow specified ipaddress for loadBalancerIP

## 6.0.0

### Major Changes

- 9bd1ec5: - Breaking change: Use revision, not current date in seeder job name
  - Allow keeping seeder jobs around after their execution
  - Configurable TTL for seeder job

### Patch Changes

- 21a2319: Allow users to set the openproject host name without using the ingress

## 5.4.0

### Minor Changes

- 6be6b9c: - allow setting `tmpStorageClassName` for /tmp and /app/tmp volumes
- a0fd7c3: Allow tolerations on seeder job

## 5.3.0

### Minor Changes

- ebc09c0: Allow definition of extraVolumes and extraVolumeMounts
- ebc09c0: Add extraVolumes and extraVolumeMounts option

## 5.2.0

### Minor Changes

- 83279c9: make sure removed secret values are actually removed

## 5.1.4

### Patch Changes

- 15014b4: update OpenProject version to 14

## 5.1.3

### Patch Changes

- 35aba8b: fix(secret_s3): add quote around port

## 5.1.2

### Patch Changes

- 68cbf0c: Allow port to be changed in s3 config

## 5.1.1

### Patch Changes

- 4ab3601: Allow to disable object storage signature v4 streaming

## 5.1.0

### Minor Changes

- 102c403: Add relative URL root configuration to health checks

## 5.0.0

### Major Changes

- b645553: Allow for multiple worker types, and defining replicas, strategy, resources

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
