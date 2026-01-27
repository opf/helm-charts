# @openproject/helm-charts

## 13.0.3

### Patch Changes

- f36401f: Upgrade OpenProject core version to 17.0.2 (patch update)

## 13.0.2

### Patch Changes

- b61b410: Upgrade OpenProject core version to 17.0.1 (patch update)

## 13.0.1

### Patch Changes

- 77f56cd: Udpate hocuspocus image

## 13.0.0

### Major Changes

- 4c68746: Upgrade OpenProject core version to 17.0.0 (major update)

## 12.1.0

### Minor Changes

- 960c661: Fix: Deployment selectors now exclude `commonLabels` to prevent immutable selector errors when upgrading from 11.5.0 to 11.6.0 or 11.7.0. This makes deployment selectors consistent with service selectors.

  This change effectively reverts parts https://github.com/opf/helm-charts/commit/236dd59117072f1f7f11864878ce061a86c471af

  ### Upgrading from version 11.6.0/11.7.0

  If you're upgrading from chart version **11.6.x** or **11.7.x** to this release, you may encounter errors about immutable Deployment selectors **if you have `commonLabels` configured**. This is because 11.6.0/11.7.0 included `commonLabels` in Deployment selectors, and this release removes them again. Kubernetes does not allow changing Deployment selectors after creation. This does NOT apply if you're still on 11.5.x.

  **Why this happens**: Your existing Deployments created by 11.6.x/11.7.x may have selectors like:

  - `app.kubernetes.io/name`, `app.kubernetes.io/instance` (from the Bitnami common chart)
  - `openproject/process`, `app.kubernetes.io/component`
  - plus any non-empty `commonLabels` you configured

  When upgrading to this release, the `commonLabels` part is intentionally removed from the selector to make selectors stable and consistent with Services. That means Kubernetes would need to change `spec.selector`, which it refuses because it’s immutable.

  If you see errors like:

  ```
  cannot patch "openproject-web" with kind Deployment: Deployment.apps "openproject-web" is invalid: spec.selector: Invalid value: ... field is immutable
  ```

  You need to delete the existing Deployments and let Helm recreate them with the new selector format. **This will cause a brief downtime** as the pods are recreated.

  > **Note**: This is a one-time migration for installations that ran 11.6.x/11.7.x with non-empty `commonLabels`. After recreating the Deployments once, future upgrades (and future `commonLabels` changes) won't hit immutable selector errors.

  **Option 1: Set labels manually**

  You can still use the `common.labels.matchLabels` value to set any values that you have had set previously, or those that were introduced in 11.6.0, these are at least:

  **web deployment**
  `- app.kubernetes.io/component=web`

  **worker-default deployment**
  `- app.kubernetes.io/component=worker-default`

  **hocuspocus deployment**
  `- app.kubernetes.io/component=hocuspocus`

  **cron deployment**
  `- app.kubernetes.io/component=cron`

  and then the matchLabels should remain as they were. If this doesn't work, you can try the following options.

  **Option 2: Use Helm's `--force` flag**

  Helm's `--force` flag can sometimes handle immutable fields by deleting and recreating resources automatically:

  ```bash
  helm upgrade --force --namespace $NAMESPACE $RELEASE_NAME openproject/openproject
  ```

  > **Note**: The `--force` flag may not always work for immutable selectors. If it fails, use one of the manual options below.

  **Option 3: Delete deployments manually (CAUTION: This deleted your deployment and causes downtime)**

  If `--force` doesn't work, manually delete the deployments before upgrading:

  ```bash
  # Set your namespace and release name
  NAMESPACE=openproject
  RELEASE_NAME=openproject

  # Delete all OpenProject deployments
  kubectl delete deployment -n $NAMESPACE \
    ${RELEASE_NAME}-web \
    ${RELEASE_NAME}-cron \
    ${RELEASE_NAME}-hocuspocus \
    ${RELEASE_NAME}-worker-default \
    ${RELEASE_NAME}-worker-bim \
    ${RELEASE_NAME}-worker-multitenancy

  # Then run your helm upgrade
  helm upgrade --namespace $NAMESPACE $RELEASE_NAME openproject/openproject
  ```

  **Option 4: Use kubectl to delete all deployments matching the release**

  ```bash
  # Set your namespace and release name
  NAMESPACE=openproject
  RELEASE_NAME=openproject

  # Delete all deployments for this release
  kubectl delete deployment -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME

  # Then run your helm upgrade
  helm upgrade --namespace $NAMESPACE $RELEASE_NAME openproject/openproject
  ```

  **Option 5: Minimize downtime with scaling (for zero-downtime upgrades)**

  If you have multiple replicas, you can minimize downtime by scaling down workers first:

  ```bash
  # Set your namespace and release name
  NAMESPACE=openproject
  RELEASE_NAME=openproject

  # Scale down workers (they can tolerate brief downtime)
  kubectl scale deployment -n $NAMESPACE \
    ${RELEASE_NAME}-worker-default \
    ${RELEASE_NAME}-worker-bim \
    ${RELEASE_NAME}-worker-multitenancy \
    --replicas=0

  # Delete all deployments
  kubectl delete deployment -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME

  # Run helm upgrade (this will recreate everything)
  helm upgrade --namespace $NAMESPACE $RELEASE_NAME openproject/openproject

  # The web deployment will be recreated first, then workers will scale back up
  ```

  > **Note**: The deployments will be automatically recreated by Helm during the upgrade. Make sure you have proper backup and recovery procedures in place before performing this operation.

## 12.0.0

### Major Changes

- 7bb67cc: Feature: enable hocuspocus by default for 17.0

## 11.7.0

### Minor Changes

- 2b44560: Add support for optional `extraEnvVars` in the Helm chart to allow users to inject additional environment variables without modifying templates.

### Patch Changes

- 38290e1: Upgrade OpenProject core version to 16.6.4 (patch update)

## 11.6.1

### Patch Changes

- 5cd2894: Upgrade OpenProject core version to 16.6.3 (patch update)
- 1166c74: Remove 'allowed domains' configuration from Hocuspocus - The value is not used anymore

## 11.6.0

### Minor Changes

- 236dd59: Add OpenShift compatibility resources and configuration
- 0b71a89: Add support for runtimeClassName, resourcesPreset, and extraTls

### Breaking Changes

- **Deployment selector changes**: This version changed how `commonLabels` are handled in Deployment selectors. If you have `commonLabels` configured. As a result, this breaks upgrades from 11.5.0, as Kubernetes does not allow changing Deployment selectors after creation. We recommend you skip 11.6.0 and 11.7.0, and go straight for versions 12+. See the steps above for how to fix this.

### Patch Changes

- df504d6: Upgrade OpenProject core version to 16.6.2 (patch update)

## 11.5.0

### Minor Changes

- 10d264f: Add component labels, namespace metadata and service account name

### Patch Changes

- 7cc7a22: Reintroduce SECRET env variable on hocuspocus - related to https://github.com/opf/helm-charts/pull/257

## 11.4.2

### Patch Changes

- 2227855: Upgrade OpenProject core version to 16.6.1 (patch update)

## 11.4.1

### Patch Changes

- ceaf68f: Set default to empty value in cron imap configuration and only roll out config if cron is enabled

## 11.4.0

### Minor Changes

- c871286: Upgrade OpenProject core version to 16.6.0 (minor update)

## 11.3.3

### Patch Changes

- 641b7db: mount tmp volume for hocuspocus under /tmp if tmp volumes are enabled

## 11.3.2

### Patch Changes

- c050882: - Remove hocuspocus SECRET environment variable as we will not be using it anymore
  - Allow hocuspocus server to use the new ALLOWED_DOMAINS env variable

## 11.3.1

### Patch Changes

- 1cd01c2: Upgrade OpenProject core version to 16.5.1 (patch update)
- 8352d05: add ingress labels

## 11.3.0

### Minor Changes

- 04c2725: Upgrade OpenProject core version to 16.5.0 (minor update)

## 11.2.0

### Minor Changes

- 316d259: Switch to bitnami secure images for development
- 9d6e5a2: Move cron-deployment resurces into values

## 11.1.2

### Patch Changes

- ed6d078: only allow for hocuspocus ingress, if hocuspocus is enabled
- b94fee6: fix broken ingress.yaml when ingress: disabled

## 11.1.1

### Patch Changes

- 13ac110: Add optional hocuspocus deployment to chart and configure OpenProject with it for use with collaborative editing (blocknotejs, behind a feature flag for now).

## 11.1.0

### Minor Changes

- 8103ece: Allow commonLabels and custom labels on deployments

## 11.0.0

### Major Changes

- ad301ad: Support HorizontalPodAutoscaling

## 10.7.0

### Minor Changes

- 644c7ad: Add nodeSelector for seeder job
- 7ae53a8: Add topologySpreadConstraints

## 10.6.0

### Minor Changes

- 2b8d656: Allow nodeSelector to be separate for web and workers

### Patch Changes

- 7dba750: Upgrade OpenProject core version to 16.4.1 (patch update)

## 10.5.0

### Minor Changes

- 8168368: Upgrade OpenProject core version to 16.4.0 (minor update)
- e4fe7b0: Added affinity to seeder job

## 10.4.2

### Patch Changes

- 70e88f4: Upgrade OpenProject core version to 16.3.2 (patch update)

## 10.4.1

### Patch Changes

- 450d949: Upgrade OpenProject core version to 16.3.1 (patch update)

## 10.4.0

### Minor Changes

- b7e0d55: Upgrade OpenProject core version to 16.3.0 (minor update)

### Patch Changes

- fd14e48: Upgrade OpenProject core version to 16.2.2 (patch update)

## 10.3.0

### Minor Changes

- b15d008: Use PostgreSQL 16 for db init

### Patch Changes

- 5c4c21c: Upgrade OpenProject core version to 16.2.1 (patch update)

## 10.2.0

### Minor Changes

- 4793ea9: Upgrade OpenProject core version to 16.2.0 (minor update)

## 10.1.2

### Patch Changes

- 32aed21: Respect existingClaim in worker deployment
- 366816a: fixing bug in the s3 existing secret logic

## 10.1.1

### Patch Changes

- e95fbf9: Upgrade OpenProject core version to 16.1.1 (patch update)

## 10.1.0

### Minor Changes

- e13d8c5: Upgrade OpenProject core version to 16.1.0 (minor update)

## 10.0.3

### Patch Changes

- 6e200a0: Upgrade OpenProject core version to 16.0.1 (patch update)

## 10.0.2

### Patch Changes

- da4f9d2: No longer override image entrypoint

## 10.0.1

### Patch Changes

- 0a3cc55: no longer use helper that was removed in most recent version of bitnami common

## 10.0.0

### Major Changes

- 5ce9fe0: Upgrade OpenProject core version to 16.0.0 (major update)

### Patch Changes

- 4e03ef9: adjust db connection pool size to fit gj workers

## 9.10.1

### Patch Changes

- ca0f0b9: Upgrade OpenProject core version to 15.5.1 (patch update)

## 9.10.0

### Minor Changes

- 1d4ce2e: Add maxThreads parameter to worker deployments.

## 9.9.0

### Minor Changes

- 37043a9: Upgrade OpenProject core version to 15.5.0 (minor update)

## 9.8.3

### Patch Changes

- febc01f: fix: Provide writable tmp volumes for db init check in cronjob

## 9.8.2

### Patch Changes

- 8a829b4: Upgrade OpenProject core version to 15.4.2 (patch update)

## 9.8.1

### Patch Changes

- fb28f95: Upgrade OpenProject core version to 15.4.1 (patch update)

## 9.8.0

### Minor Changes

- cf9bf22: Upgrade OpenProject core version to 15.4.0 (minor update)
- 1f9a03f: Allow passing existing secret for admin user

## 9.7.2

### Patch Changes

- 45fe903: Upgrade OpenProject core version to 15.3.2 (patch update)

## 9.7.1

### Patch Changes

- 27bc8dd: Upgrade OpenProject core version to 15.3.1 (patch update)

## 9.7.0

### Minor Changes

- bdf058a: Upgrade OpenProject core version to 15.3.0 (minor update)

## 9.6.0

### Minor Changes

- 7679fee: Define more options for postgresql connection
- 846b5a7: also provide writable tmp volumes for db init check

## 9.5.1

### Patch Changes

- bbe9149: Upgrade OpenProject core version to 15.2.1 (patch update)

## 9.5.0

### Minor Changes

- 8e0fc0d: Upgrade OpenProject core version to 15.2.0 (minor update)

## 9.4.1

### Patch Changes

- 56f9c4f: Upgrade OpenProject core version to 15.1.1 (patch update)

## 9.4.0

### Minor Changes

- 5d31b44: Bump version to 15.1.0

## 9.3.0

### Minor Changes

- a5f14c9: Add support for the cron-based service for incoming email check via IMAP

## 9.2.0

### Minor Changes

- 50a9eee: Allow setting admin user seeder as locked

## 9.1.0

### Minor Changes

- 4a5513c: Upgrade OpenProject core version to 15.1.0 (minor update)

## 9.0.1

### Patch Changes

- cb5a1ed: Upgrade OpenProject core version to 15.0.2 (patch update)

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
