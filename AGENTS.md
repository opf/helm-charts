# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Repository Overview

This is the OpenProject Helm Charts repository, containing Kubernetes deployment configurations for the OpenProject project management software (`charts/openproject`) and supporting charts (`charts/llm-stack`). The repository is structured as a self-contained Helm chart registry published via GitHub Pages using Helm's chart-releaser action.

## Key Commands

### Testing
- `bundle install` - Install Ruby dependencies for testing
- `bin/rspec` - Run the complete RSpec test suite for Helm templates
- `bin/rspec spec/charts/openproject/<specific_test>.rb` - Run individual test files

### Release Management
- `npm run changeset:version` - Update version numbers and generate changelog using changesets
- `bin/update_from_core_release <version>` - Update chart to track a new OpenProject core release
- `script/version` - Sync each chart's Chart.yaml version with its own `charts/<chart>/package.json` version

### Helm Operations
- `helm dependency update` - Update chart dependencies (required before testing)
- `helm template --debug optest . -f -` - Debug template rendering with custom values
- `helm lint charts/openproject` - Validate chart syntax and structure

## Architecture

### Chart Structure
The main chart is located in `charts/openproject/` and follows standard Helm conventions:
- `Chart.yaml` - Chart metadata, dependencies, and versioning
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes resource templates with Go templating
- `templates/_helpers.tpl` - Shared template helpers and functions

### Key Components
The chart deploys OpenProject with these main components:
- **Web deployment** (`web-deployment.yaml`) - Main OpenProject web application
- **Worker deployment** (`worker-deployment.yaml`) - Background job processing (GoodJob)
- **Cron deployment** (`cron-deployment.yaml`) - Scheduled tasks (e.g., IMAP incoming emails)
- **Seeder job** (`seeder-job.yaml`) - Database migration (`migrate` init container) and seeding (`seeder` container)
- **Hocuspocus deployment** (`hocuspocus-deployment.yaml`) - Optional bundled WebSocket backend for real-time collaborative editing
- **AnyCable deployment** (`anycable-deployment.yaml`) - Optional bundled AnyCable server for live page updates
- **RustFS deployment & bucket job** (`rustfs-deployment.yaml`, `rustfs-bucket-job.yaml`) - Optional bundled single-node S3-compatible object store

### Dependencies
External dependencies managed via `Chart.yaml`:
- PostgreSQL (Bitnami chart) - Database backend
- Memcached (Bitnami chart) - Caching layer
- Common (Bitnami chart) - Shared utilities

### Testing Framework
Uses Ruby RSpec with custom `HelmTemplate` class (`spec/helm_template.rb`) to:
- Render Helm templates with test values
- Parse generated Kubernetes YAML
- Assert on resource configurations and relationships
- Test various configuration scenarios (S3, OIDC, scaling, security contexts, probes, etc.)

## Chart Implementation & Review Checklist

Verify these requirements whenever adding or modifying templates, workloads, or values:

### 1. Pod Security Standards (`restricted`) & Volumes
- **Security contexts everywhere**: Every pod and container (including `initContainers`, `seeder`, `cron`, Helm test pods, and optional components like `hocuspocus`, `anycable`, `rustfs`) must include `openproject.podSecurityContext` and `openproject.containerSecurityContext` and use only restricted volume types ([#343](https://github.com/opf/helm-charts/pull/343), [#345](https://github.com/opf/helm-charts/pull/345), [#272](https://github.com/opf/helm-charts/pull/272), [#23](https://github.com/opf/helm-charts/pull/23)).
- **Test disabled-by-default workloads**: Add a context in `spec/charts/openproject/security_context_spec.rb` for any optional workload disabled by default ([#343](https://github.com/opf/helm-charts/pull/343), [#364](https://github.com/opf/helm-charts/pull/364)).
- **Non-root init containers & writable `/tmp`**: Never `chmod`/`chown` mount points as root; use non-root owned subdirectories (`prepare-tmpdir` / `TMPDIR=/tmp/ruby`) ([#332](https://github.com/opf/helm-charts/pull/332)). Mount writable `/tmp` volumes whenever `readOnlyRootFilesystem: true` on all containers and init containers that need `/tmp` (`wait-for-db`, `migrate`, `cron`, `seeder`, `hocuspocus`) ([#334](https://github.com/opf/helm-charts/pull/334), [#260](https://github.com/opf/helm-charts/pull/260), [#185](https://github.com/opf/helm-charts/pull/185), [#170](https://github.com/opf/helm-charts/pull/170), [#68](https://github.com/opf/helm-charts/pull/68)).
- **Chart packaging**: Keep `templates/tests/` and `examples/` in `.helmignore` ([#344](https://github.com/opf/helm-charts/pull/344)).

### 2. Probes (Kyverno Compliance)
- **Probes on all deployments**: Every `Deployment` (`web`, `worker`, `cron`, `hocuspocus`, `anycable`) must define `livenessProbe` and `readinessProbe` enabled by default, using `openproject.mergedProbe` and `openproject.probeSettings` for global (`probes.*`) and per-component (`<component>.probes.*`) configurability ([#373](https://github.com/opf/helm-charts/pull/373), [#131](https://github.com/opf/helm-charts/pull/131)).
- **Rails probe path & headers**: Prefix OpenProject HTTP probe paths with `openproject.railsRelativeUrlRoot` and pass `Host: localhost` ([#93](https://github.com/opf/helm-charts/pull/93)).

### 3. Secrets, Claims & GitOps (ArgoCD) Compatibility
- **Respect `persistence.existingClaim`**: Check `persistence.existingClaim` before falling back to the chart PVC name in `web`, `worker`, `cron`, and `seeder`, and skip mounting when `s3.enabled` or `rustfs.bundled` is active ([#367](https://github.com/opf/helm-charts/pull/367), [#204](https://github.com/opf/helm-charts/pull/204), [#27](https://github.com/opf/helm-charts/pull/27)).
- **Reset Secret `data:`**: Include `data: # reset data to make sure only keys defined below remain` above `stringData:` in every `secret_*.yaml` so removed keys do not linger on upgrade ([#113](https://github.com/opf/helm-charts/pull/113)).
- **Auto-generated Secrets**: Only render `*-auto-generated` Secrets when the component is enabled, no `existingSecret` or `environment.<VAR>` override is set, and `lookup` in `.Release.Namespace` finds no existing secret; annotate with `"helm.sh/resource-policy": "keep"` ([#336](https://github.com/opf/helm-charts/pull/336), [#328](https://github.com/opf/helm-charts/pull/328), [#325](https://github.com/opf/helm-charts/pull/325)).
- **Don't clobber external credentials**: Omit default/empty credential keys when `existingSecret` or `s3.useIamProfile` is used, and prefer `secretKeyRef`/`envFrom` over `lookup` so ArgoCD/offline rendering works ([#331](https://github.com/opf/helm-charts/pull/331), [#213](https://github.com/opf/helm-charts/pull/213), [#87](https://github.com/opf/helm-charts/pull/87), [#72](https://github.com/opf/helm-charts/pull/72), [#70](https://github.com/opf/helm-charts/pull/70)).
- **GitOps-safe names & keys**: Use `.Release.Revision` instead of `now`/timestamps in Job names ([#120](https://github.com/opf/helm-charts/pull/120)). Avoid `nil` values in rendered Secret maps (`values.yaml` should use `""` or omit conditionally) and only deploy component secrets when the component is enabled ([#243](https://github.com/opf/helm-charts/pull/243)).
- **Omit unset optional env vars**: Do not render empty strings for env vars whose mere presence alters behavior (`OPENPROJECT_SEED_LOCALE`, `OPENPROJECT_HOST__NAME` when `ingress.enabled: false` and `openproject.host` is empty, `OPENPROJECT_SEED_ADMIN_USER_LOCKED`) ([#300](https://github.com/opf/helm-charts/pull/300), [#161](https://github.com/opf/helm-charts/pull/161), [#150](https://github.com/opf/helm-charts/pull/150), [#148](https://github.com/opf/helm-charts/pull/148)).

### 4. YAML & Template Hygiene
- **Quote scalars & guard composite strings**: Quote ports, numbers, and booleans in `stringData`/`env` ([#102](https://github.com/opf/helm-charts/pull/102)). Guard `"{{ .host }}:{{ .port }}"` with `if and .host .port` so unconfigured values don't render invalid `":"` ([#297](https://github.com/opf/helm-charts/pull/297)).
- **Whitespace chomping**: Avoid trailing `-}}` before newline-indented YAML keys, which can swallow indentation when conditional branches toggle ([#150](https://github.com/opf/helm-charts/pull/150)).
- **Container ports**: Only use valid Kubernetes fields (`name`, `containerPort`, `protocol`) under container `ports:`—never `port:` ([#287](https://github.com/opf/helm-charts/pull/287)).

### 5. Cross-Workload Consistency
Apply pod/container options consistently across `web`, `worker`, `cron`, `seeder` (including `initContainers`), and bundled services (`hocuspocus`, `anycable`, `rustfs`):
- **Egress TLS / Custom CA (`egress.tls.rootCA`)**: Mount `ca-pemstore`, set `SSL_CERT_FILE`, and when `replaceSystemStore: true` is set, also set `SSL_CERT_DIR: "/nonexistent"` (plus `NODE_OPTIONS: --use-openssl-ca` and `NODE_EXTRA_CA_CERTS` on Node pods) ([#377](https://github.com/opf/helm-charts/pull/377), [#347](https://github.com/opf/helm-charts/pull/347), [#304](https://github.com/opf/helm-charts/pull/304), [#302](https://github.com/opf/helm-charts/pull/302)).
- **DB & Worker env vars**: Set `PGPASSWORD` alongside `OPENPROJECT_DB_PASSWORD` on all OpenProject containers so `psql` in `migrate` can authenticate ([#371](https://github.com/opf/helm-charts/pull/371), [#368](https://github.com/opf/helm-charts/pull/368)). When `workerValues.maxThreads` is set, also set `RAILS_MAX_THREADS` to `add $workerValues.maxThreads 3` ([#192](https://github.com/opf/helm-charts/pull/192)).
- **Images & pull secrets**: Use `openproject.imagePullSecrets` on every pod spec ([#79](https://github.com/opf/helm-charts/pull/79)) and image helpers supporting `registry`, `repository`, `tag`, `sha256` digest, and `imagePullPolicy` fallback ([#294](https://github.com/opf/helm-charts/pull/294)).
- **Resources & presets**: Use `<component>.resources` and `coalesce .Values.<component>.resourcesPreset .Values.resourcesPreset` (do not accidentally reference `.Values.resources`, another component's `resourcesPreset`, or `dbInit` resources on `appInit` containers) ([#298](https://github.com/opf/helm-charts/pull/298), [#270](https://github.com/opf/helm-charts/pull/270), [#137](https://github.com/opf/helm-charts/pull/137)).
- **Scheduling, runtime & escape hatches**: Support `affinity`, `tolerations`, `nodeSelector` (with per-component `coalesce`), `topologySpreadConstraints`, `runtimeClassName`, `serviceAccountName`, `extraEnvVars`, `extraVolumes`, and `extraVolumeMounts` ([#377](https://github.com/opf/helm-charts/pull/377), [#364](https://github.com/opf/helm-charts/pull/364), [#276](https://github.com/opf/helm-charts/pull/276), [#270](https://github.com/opf/helm-charts/pull/270), [#267](https://github.com/opf/helm-charts/pull/267), [#236](https://github.com/opf/helm-charts/pull/236), [#234](https://github.com/opf/helm-charts/pull/234), [#233](https://github.com/opf/helm-charts/pull/233)).
- **Strategy & HPA**: Render the full `strategy` map via `toYaml` ([#146](https://github.com/opf/helm-charts/pull/146)), and omit `spec.replicas` on `web-deployment.yaml` when `autoscaling.enabled: true` ([#232](https://github.com/opf/helm-charts/pull/232)).

### 6. Labels, Annotations, Selectors, Ingress & NetworkPolicies
- **Immutable `spec.selector.matchLabels`**: **Never** include `commonLabels` or `app.kubernetes.io/component` in `Deployment` `spec.selector.matchLabels` (only `common.labels.matchLabels .` + `openproject/process`), or changing `commonLabels` breaks upgrades ([#281](https://github.com/opf/helm-charts/pull/281)).
- **Metadata labels & annotations**: Pass `(dict "customLabels" .Values.commonLabels "context" $)` to `common.labels.standard` on resource and pod `metadata.labels`, merge component annotations with `commonAnnotations`, and include `openproject.envChecksums` on pods consuming chart secrets ([#323](https://github.com/opf/helm-charts/pull/323), [#267](https://github.com/opf/helm-charts/pull/267), [#255](https://github.com/opf/helm-charts/pull/255), [#35](https://github.com/opf/helm-charts/pull/35)).
- **Ingress & NetworkPolicy guards**: Guard component ingress paths with `<component>.enabled` ([#248](https://github.com/opf/helm-charts/pull/248)), ensure `ingress.enabled: false` renders cleanly ([#246](https://github.com/opf/helm-charts/pull/246)), and allow required in-cluster ingress/egress between `web`/`worker`/`cron` and bundled services when `networkPolicy` restricts traffic ([#272](https://github.com/opf/helm-charts/pull/272)).

## Version Management

This repository uses a dual-versioning approach:
- **Chart version** (`Chart.yaml` version field) - Helm chart releases
- **App version** (`Chart.yaml` appVersion field) - OpenProject core version being deployed

The `bin/update_from_core_release` script automates updating to new OpenProject releases by:
1. Updating `appVersion` in Chart.yaml
2. Updating image tags in values.yaml
3. Creating appropriate changeset files for release tracking

## Release Process

Uses Changesets for automated release management:
- `.changeset/` directory contains pending changes
- Each chart under `charts/*` is its own npm workspace package (see `charts/<chart>/package.json`), versioned independently by changesets. A changeset's frontmatter names the package(s) it bumps (e.g. `"openproject": patch`), so a change scoped to one chart only versions and releases that chart.
- `npm run changeset:version` processes changesets and updates versions
- Chart releases are automated via GitHub Actions with chart-releaser, which creates one GitHub Release per chart (tagged `<chart-name>-<version>`) and only for charts whose version actually changed
- Charts are signed using GPG key (fingerprint in `Chart.yaml` annotations)

## Development Workflow

1. Make changes to chart templates or values
2. Update chart dependencies: `helm dependency update`
3. Run tests: `bin/rspec`
4. For core version updates: `bin/update_from_core_release <version>`
5. For chart changes: Create changeset files in `.changeset/`
6. Version and release: `npm run changeset:version`

## Key Files
- `charts/openproject/Chart.yaml:8` - App version (OpenProject core version)
- `charts/openproject/Chart.yaml:9` - Chart version
- `charts/openproject/package.json` - NPM package version for this chart (synced into Chart.yaml by `script/version`)
- `spec/helm_template.rb` - Test framework for Helm template rendering
- `bin/update_from_core_release` - Core version update automation
