{{/*
Returns the OpenProject image to be used including the respective registry and image tag.
*/}}
{{- define "openproject.image" -}}
{{ .Values.image.registry }}/{{ .Values.image.repository }}{{ if .Values.image.sha256 }}@sha256:{{ .Values.image.sha256 }}{{ else }}:{{ .Values.image.tag }}{{ end }}
{{- end -}}

{{/*
Returns the Hocuspocus image to be used including registry, tag and optional digest.

If a sha256 digest is provided, we render `image:tag@sha256:digest` (tag is kept for traceability).
*/}}
{{- define "openproject.hocuspocus.image" -}}
{{- $img := .Values.hocuspocus.image -}}
{{- $registry := required "hocuspocus.image.registry is required" $img.registry -}}
{{- $repository := required "hocuspocus.image.repository is required" $img.repository -}}
{{- $tag := required "hocuspocus.image.tag is required" ($img.tag | toString) -}}
{{- if $img.sha256 -}}
{{ $registry }}/{{ $repository }}:{{ $tag }}@sha256:{{ $img.sha256 }}
{{- else -}}
{{ $registry }}/{{ $repository }}:{{ $tag }}
{{- end -}}
{{- end -}}

{{/*
Returns the Hocuspocus imagePullPolicy with a safe fallback.
*/}}
{{- define "openproject.hocuspocus.imagePullPolicy" -}}
{{- default .Values.image.imagePullPolicy .Values.hocuspocus.image.imagePullPolicy -}}
{{- end -}}

{{/*
Returns the OpenProject image pull secrets, if any are defined
*/}}
{{- define "openproject.imagePullSecrets" -}}
{{- if or .Values.imagePullSecrets .Values.global.imagePullSecrets }}
imagePullSecrets:
  {{- range (coalesce .Values.imagePullSecrets .Values.global.imagePullSecrets) }}
  - name: "{{ . }}"
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Returns extra volume definitons when defined as values.extraVolumes
*/}}
{{- define "openproject.extraVolumes" -}}
{{- if .Values.extraVolumes }}
{{ include "common.tplvalues.render" (dict "value" .Values.extraVolumes  "context" .) }}
{{- end }}
{{- end -}}

{{/*
Returns extra volume mounts definitons when defined as values.extraVolumeMounts
*/}}
{{- define "openproject.extraVolumeMounts" -}}
{{- if .Values.extraVolumeMounts }}
{{ include "common.tplvalues.render" (dict "value" .Values.extraVolumeMounts "context" .) }}
{{- end }}
{{- end -}}

{{/*
Yields the configured container security context if enabled.

Allows writing to the container file system in development mode
This way the OpenProject container works without mounted tmp volumes
which may not work correctly in local development clusters.
*/}}
{{- define "openproject.containerSecurityContext" }}
{{- if .Values.containerSecurityContext.enabled }}
securityContext:
  {{-
    mergeOverwrite
      (omit .Values.containerSecurityContext "enabled" | deepCopy)
      (dict "readOnlyRootFilesystem" (and
        (not .Values.develop)
        (get .Values.containerSecurityContext "readOnlyRootFilesystem")
      ))
    | toYaml
    | nindent 2
  }}
{{- end }}
{{- end }}

{{/* Yields the configured pod security context if enabled. */}}
{{- define "openproject.podSecurityContext" }}
{{- if .Values.podSecurityContext.enabled }}
securityContext:
  {{ omit .Values.podSecurityContext "enabled" | toYaml | nindent 2 | trim }}
{{- end }}
{{- end }}


{{- define "openproject.useTmpVolumes" -}}
{{- if ne .Values.openproject.useTmpVolumes nil -}}
  {{- .Values.openproject.useTmpVolumes -}}
{{- else -}}
  {{- .Values.containerSecurityContext.readOnlyRootFilesystem -}}
{{- end -}}
{{- end -}}

{{- define "openproject.fixTmpVolumePermissions" -}}
{{- if and (eq (include "openproject.useTmpVolumes" .) "true") .Values.openproject.tmpVolumesPermissionFix -}}
  {{- true -}}
{{- else -}}
  {{- false -}}
{{- end -}}
{{- end -}}

{{/*
Init container that prepares a sticky-bit tmp directory for Ruby's Dir.tmpdir.

Some CSI drivers mount the tmp volume world-writable without the sticky bit,
which Ruby rejects ("could not find a temporary directory"). We create an
owned subdirectory and set the sticky bit on it as the non-root app user, so
no elevated privileges are required (unlike chmod'ing the mount point itself).
TMPDIR is pointed at this directory in "openproject.env".
*/}}
{{- define "openproject.tmpVolumeInitContainer" -}}
{{- if eq (include "openproject.fixTmpVolumePermissions" .) "true" }}
- name: prepare-tmpdir
  {{- include "openproject.containerSecurityContext" . | indent 2 }}
  image: {{ include "openproject.image" . }}
  imagePullPolicy: {{ .Values.image.imagePullPolicy }}
  command:
    - sh
    - -c
    - mkdir -p /tmp/ruby && chmod 1777 /tmp/ruby
  {{- if .Values.appInit.resources }}
  resources:
    {{- toYaml .Values.appInit.resources | nindent 4 }}
  {{- else if ne .Values.appInit.resourcesPreset "none" }}
  resources:
    {{- include "common.resources.preset" (dict "type" .Values.appInit.resourcesPreset) | nindent 4 }}
  {{- end }}
  volumeMounts:
    {{- include "openproject.tmpVolumeMounts" . | indent 4 }}
{{- end }}
{{- end -}}

{{/*
Returns the internal (cluster-only) hostname of the bundled RustFS instance's S3 API service.
*/}}
{{- define "openproject.rustfsServiceHost" -}}
{{- printf "%s-rustfs-svc" (include "common.names.fullname" .) -}}
{{- end -}}

{{- define "openproject.rustfsFullname" -}}
{{- printf "%s-rustfs" (include "common.names.fullname" .) -}}
{{- end -}}

{{- define "openproject.tmpVolumeMounts" -}}
{{- if eq (include "openproject.useTmpVolumes" .) "true" }}
- mountPath: /tmp
  name: tmp
- mountPath: /app/tmp
  name: app-tmp
{{- end }}
{{- end -}}

{{- define "hocuspocus.tmpVolumeMounts" -}}
{{- if eq (include "openproject.useTmpVolumes" .) "true" }}
- mountPath: /tmp
  name: tmp
{{- end }}
{{- end -}}

{{- define "openproject.tmpVolumeSpec" -}}
{{- if eq (include "openproject.useTmpVolumes" .) "true" }}
- name: tmp
  # we can't use emptyDir due to the sticky bit issue
  # see: https://github.com/kubernetes/kubernetes/issues/110835
  ephemeral:
    volumeClaimTemplate:
      metadata:
        creationTimestamp: null
        {{- if .Values.openproject.tmpVolumesAnnotations }}
        annotations:
          {{ .Values.openproject.tmpVolumesAnnotations | toYaml }}
        {{- end }}
        {{- if .Values.openproject.tmpVolumesLabels }}
        labels:
          {{ .Values.openproject.tmpVolumesLabels | toYaml }}
        {{- end }}
      spec:
        accessModes: ["ReadWriteOnce"]
        {{- if or .Values.openproject.tmpVolumesStorageClassName .Values.persistence.storageClassName }}
        storageClassName: {{ coalesce .Values.openproject.tmpVolumesStorageClassName .Values.persistence.storageClassName }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.openproject.tmpVolumesStorage }}
- name: app-tmp
  # we can't use emptyDir due to the sticky bit / world writable issue
  # see: https://github.com/kubernetes/kubernetes/issues/110835
  ephemeral:
    volumeClaimTemplate:
      metadata:
        creationTimestamp: null
        {{- if .Values.openproject.tmpVolumesAnnotations }}
        annotations:
          {{ .Values.openproject.tmpVolumesAnnotations | toYaml }}
        {{- end }}
        {{- if .Values.openproject.tmpVolumesLabels }}
        labels:
          {{ .Values.openproject.tmpVolumesLabels | toYaml }}
        {{- end }}
      spec:
        accessModes: ["ReadWriteOnce"]
        {{- if or .Values.openproject.tmpVolumesStorageClassName .Values.persistence.storageClassName }}
        storageClassName: {{ coalesce .Values.openproject.tmpVolumesStorageClassName .Values.persistence.storageClassName }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.openproject.tmpVolumesStorage }}
{{- end }}
{{- end -}}

{{- define "openproject.envFrom" -}}
- secretRef:
    name: {{ include "common.names.fullname" . }}-core
{{- if .Values.openproject.oidc.enabled }}
- secretRef:
    name: {{ include "common.names.fullname" . }}-oidc
{{- end }}
{{- if or .Values.s3.enabled .Values.rustfs.bundled }}
- secretRef:
    name: {{ include "common.names.fullname" . }}-s3
{{- end }}
{{- if and (not .Values.rustfs.bundled) .Values.s3.auth.existingSecret }}
- secretRef:
    name: {{ .Values.s3.auth.existingSecret }}
{{- end }}
{{- if eq .Values.openproject.cache.store "memcache" }}
- secretRef:
    name: {{ include "common.names.fullname" . }}-memcached
{{- end }}
{{- if .Values.environment }}
- secretRef:
    name: {{ include "common.names.fullname" . }}-environment
{{- end }}
{{- if .Values.openproject.extraEnvVarsSecret }}
- secretRef:
    name: {{ .Values.openproject.extraEnvVarsSecret }}
{{- end }}
{{- if .Values.openproject.oidc.extraOidcSealedSecret }}
- secretRef:
    name: {{ .Values.openproject.oidc.extraOidcSealedSecret }}
{{- end }}
{{- end }}

{{- define "openproject.env" -}}
{{- if eq (include "openproject.fixTmpVolumePermissions" .) "true" }}
- name: TMPDIR
  value: /tmp/ruby
{{- end }}
{{- if .Values.metrics.enabled }}
- name: OPENPROJECT_METRICS_ENABLED
  value: "true"
{{- end }}
{{- if .Values.egress.tls.rootCA.fileName }}
- name: SSL_CERT_FILE
  value: "/etc/ssl/certs/custom-ca.pem"
{{- if .Values.egress.tls.rootCA.replaceSystemStore }}
- name: SSL_CERT_DIR
  value: "/nonexistent"
{{- end }}
{{- end }}
{{- if .Values.rustfs.bundled }}
{{/* The credentials secret (auto-generated or user-provided) stores these under RustFS's own
     RUSTFS_ACCESS_KEY/RUSTFS_SECRET_KEY names, not duplicated under OpenProject's own env var
     names too -- mapped in explicitly here instead. */}}
- name: OPENPROJECT_FOG_CREDENTIALS_AWS__ACCESS__KEY__ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.rustfs.secret.existingSecret }}
      key: RUSTFS_ACCESS_KEY
- name: OPENPROJECT_FOG_CREDENTIALS_AWS__SECRET__ACCESS__KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.rustfs.secret.existingSecret }}
      key: RUSTFS_SECRET_KEY
{{- end }}
{{/* PGPASSWORD too: DATABASE_URL carries no password, but docker/prod/migrate probes the DB with psql. */}}
{{- range $envName := list "OPENPROJECT_DB_PASSWORD" "PGPASSWORD" }}
{{- if $.Values.postgresql.auth.existingSecret }}
- name: {{ $envName }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.postgresql.auth.existingSecret }}
      key: {{ $.Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- else if $.Values.postgresql.auth.password }}
- name: {{ $envName }}
  value: {{ $.Values.postgresql.auth.password }}
{{- else }}
- name: {{ $envName }}
  valueFrom:
    secretKeyRef:
      name: {{ include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" $.Values.postgresql "context" $) }}
      key: {{ $.Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- end }}
{{- end }}
{{- if .Values.openproject.realtime_collaboration.enabled }}
# External backend: we are using an external hocuspocus backend with an existing secret containing the password
{{- if .Values.openproject.realtime_collaboration.hocuspocus.auth.existingSecret }}
- name: OPENPROJECT_COLLABORATIVE__EDITING__HOCUSPOCUS__SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openproject.realtime_collaboration.hocuspocus.auth.existingSecret }}
      key: {{ .Values.openproject.realtime_collaboration.hocuspocus.auth.secretKey }}
# Included backend: we are using the included hocuspocus backend and configure its secret to connect the frontend, looking it up in an existing secret
{{- else if .Values.hocuspocus.auth.existingSecret }}
- name: OPENPROJECT_COLLABORATIVE__EDITING__HOCUSPOCUS__SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.hocuspocus.auth.existingSecret }}
      key: {{ .Values.hocuspocus.auth.secretKey }}
# if nothing at all was defined, we use an auto generated secret (see secret_hocuspocus.yaml)
# this will also be used by the included backend
{{- else }}
- name: OPENPROJECT_COLLABORATIVE__EDITING__HOCUSPOCUS__SECRET
  valueFrom:
    secretKeyRef:
      name: hocuspocus-secret-auto-generated
      key: secret
{{- end }}
{{- end }}
{{- if not (hasKey (default (dict) .Values.environment) "SECRET_KEY_BASE") }}
{{- if .Values.openproject.secretKeyBase.existingSecret }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openproject.secretKeyBase.existingSecret }}
      key: {{ .Values.openproject.secretKeyBase.secretKey }}
# if nothing was defined, we use an auto generated secret (see secret_secret_key_base.yaml)
{{- else }}
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: secret-key-base-auto-generated
      key: secret-key-base
{{- end }}
{{- end }}
{{- if .Values.extraEnvVars }}
{{- toYaml .Values.extraEnvVars | nindent 0 }}
{{- end }}
{{- end }}

{{- define "openproject.envChecksums" }}
# annotate pods with env value checksums so changes trigger re-deployments
{{/* If I knew how to map and reduce a range in helm I would do that and use a single checksum. But here we are. */}}
{{- range $suffix := list "core" "memcached" "oidc" "s3" "environment" }}
checksum/env-{{ $suffix }}: {{ include (print $.Template.BasePath "/secret_" $suffix ".yaml") $ | sha256sum }}
{{- end }}
{{- end }}

{{/*
Returns the KOPIA_PASSWORD env entry for backup pods.
When kopiaPassword is set directly in values it is already present in the backup
secret (via envFrom), so no explicit env entry is needed.
Otherwise the password is sourced from existingSecret or the auto-generated secret.
*/}}
{{- define "openproject.backup.kopiaPasswordEnv" -}}
{{- if not .Values.backup.kopiaPassword }}
- name: KOPIA_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- if .Values.backup.existingSecret }}
      name: {{ .Values.backup.existingSecret }}
      key: {{ .Values.backup.secretKeys.kopiaPassword }}
      {{- else }}
      name: backup-kopia-password-auto-generated
      key: kopiaPassword
      {{- end }}
{{- end }}
{{- end }}

{{/*
Image of the kopia containers in backup pods.
*/}}
{{- define "openproject.backup.image" -}}
"{{ .Values.backup.image.registry }}/{{ .Values.backup.image.repository }}:{{ .Values.backup.image.tag }}"
{{- end }}

{{/*
Image of the database dump init container in backup pods.
*/}}
{{- define "openproject.backup.dbDumpImage" -}}
"{{ .Values.backup.dbDump.image.registry }}/{{ .Values.backup.dbDump.image.repository }}:{{ include "openproject.backup.dbDumpImageTag" . }}"
{{- end }}

{{/*
Tag of the database dump image: backup.dbDump.image.tag or, if empty, "<major>-alpine" with the major
version of the bundled PostgreSQL, so pg_dump matches the server. For an external database the
tag has to be set explicitly, as the server's version is unknown here.
*/}}
{{- define "openproject.backup.dbDumpImageTag" -}}
{{- if .Values.backup.dbDump.image.tag -}}
{{- .Values.backup.dbDump.image.tag -}}
{{- else if .Values.postgresql.bundled -}}
{{- $major := regexFind "^[0-9]+" (toString .Values.postgresql.image.tag) -}}
{{- if not $major -}}
{{- fail (printf "backup: cannot determine the major version of the bundled PostgreSQL from postgresql.image.tag %q. Set backup.dbDump.image.tag to a postgres image tag of the same major version, e.g. \"15-alpine\"." (toString .Values.postgresql.image.tag)) -}}
{{- end -}}
{{- printf "%s-alpine" $major -}}
{{- else -}}
{{- fail "backup: set backup.dbDump.image.tag to a postgres image tag matching the major version of your database server, e.g. \"16-alpine\" for PostgreSQL 16 (see backup.dbDump in values.yaml)." -}}
{{- end -}}
{{- end }}

{{/*
Returns "true" if OpenProject stores attachments in S3: an external one (s3.enabled) or the
bundled RustFS (rustfs.bundled).
*/}}
{{- define "openproject.backup.s3Attachments" -}}
{{- if or .Values.s3.enabled .Values.rustfs.bundled -}}
true
{{- end -}}
{{- end }}

{{/*
Returns "true" if the backup has to mount the OpenProject S3 bucket itself via rclone/FUSE,
which requires a privileged container. That is the case for attachments stored in S3 unless
the bucket is provided as a volume (backup.s3Attachments.existingClaim), e.g. via a CSI driver.
*/}}
{{- define "openproject.backup.fuse" -}}
{{- if and (include "openproject.backup.s3Attachments" .) (not .Values.backup.s3Attachments.existingClaim) -}}
true
{{- end -}}
{{- end }}

{{/*
Fails the installation if the backup needs a privileged container (see openproject.backup.fuse)
but the namespace enforces a Pod Security Standard which forbids that, as the backup pods would
then be rejected on every run. Can only check real installs (and --dry-run=server), as the
namespace cannot be looked up in `helm template`.
*/}}
{{- define "openproject.backup.checkPodSecurity" -}}
{{- if include "openproject.backup.fuse" . }}
{{- $namespace := lookup "v1" "Namespace" "" .Release.Namespace }}
{{- $level := dig "metadata" "labels" "pod-security.kubernetes.io/enforce" "" ($namespace | default dict) }}
{{- if has $level (list "baseline" "restricted") }}
{{- fail (printf "\n\nbackup: Attachments are stored in S3 (s3.enabled or rustfs.bundled), which the backup can only read by mounting the bucket via FUSE in a privileged container. But namespace %q enforces the %q Pod Security Standard, so the backup pods would be rejected.\n\nProvide the bucket as a volume instead, e.g. via an S3 CSI driver, and set backup.s3Attachments.existingClaim (see the chart's README, section \"Backups of S3 attachments\").\n" .Release.Namespace $level) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Pod-level settings shared by all backup pods: service account and security context.
*/}}
{{- define "openproject.backup.podSettings" -}}
{{- if .Values.backup.serviceAccountName }}
serviceAccountName: {{ .Values.backup.serviceAccountName }}
{{- end }}
{{- if .Values.podSecurityContext.enabled }}
securityContext:
  {{- omit .Values.podSecurityContext "enabled" | merge (dict "fsGroupChangePolicy" "OnRootMismatch") | toYaml | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Returns backup.s3Attachments.path, the location of OpenProject's "uploads" directory
within the S3 attachments volume, as a relative path ("" for the root of the volume).
*/}}
{{- define "openproject.backup.s3AttachmentsSubPath" -}}
{{- $path := .Values.backup.s3Attachments.path | default "" | clean | trimPrefix "/" -}}
{{- if ne $path "." }}{{ $path }}{{ end -}}
{{- end }}

{{/*
Returns the local attachments storage path relative to the assets PVC (mounted at
/var/openproject/assets), e.g. "files" for OpenProject's default /var/openproject/assets/files.
Taken from backup.attachmentsStoragePath, else environment.OPENPROJECT_ATTACHMENTS__STORAGE__PATH.
*/}}
{{- define "openproject.backup.attachmentsSubPath" -}}
{{- $mountPath := "/var/openproject/assets" -}}
{{- $path := .Values.backup.attachmentsStoragePath | default (get .Values.environment "OPENPROJECT_ATTACHMENTS__STORAGE__PATH") | default (printf "%s/files" $mountPath) | clean -}}
{{- if not (or (eq $path $mountPath) (hasPrefix (printf "%s/" $mountPath) $path)) -}}
{{- fail (printf "backup: the attachments storage path %q is not on the assets volume (%s), so it cannot be backed up. Set backup.attachmentsStoragePath to the path OpenProject stores attachments in." $path $mountPath) -}}
{{- end -}}
{{- trimPrefix "/" (trimPrefix $mountPath $path) -}}
{{- end }}

{{/*
Returns the kopia cache volume for backup pods: the shared cache PVC or, if
backup.cache.persistent is false, an emptyDir.
*/}}
{{- define "openproject.backup.cacheVolume" -}}
- name: backup-cache
{{- if .Values.backup.cache.persistent }}
  persistentVolumeClaim:
    claimName: {{ include "common.names.fullname" . }}-backup-cache
{{- else }}
  emptyDir: {}
{{- end }}
{{- end }}

{{/*
Returns the PGPASSWORD env entry sourcing the database password for pg_dump in the db-dump init container.
Mirrors the OPENPROJECT_DB_PASSWORD logic from openproject.env.
*/}}
{{- define "openproject.backup.pgPasswordEnv" -}}
{{- if .Values.postgresql.auth.existingSecret }}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.auth.existingSecret }}
      key: {{ .Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- else if .Values.postgresql.auth.password }}
- name: PGPASSWORD
  value: {{ .Values.postgresql.auth.password }}
{{- else }}
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) }}
      key: {{ .Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openproject.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders the shared timing settings of a probe from .Values.probes.<liveness|readiness|startup>.
*/}}
{{- define "openproject.probeSettings" -}}
{{- pick . "initialDelaySeconds" "timeoutSeconds" "periodSeconds" "failureThreshold" "successThreshold" | toYaml }}
{{- end }}

{{/*
Merges component-specific probe overrides over the global probe settings and returns the result as YAML.
Every key set in "overrides" wins, including zero values like `0` or `false` (unlike sprig's `merge`).

Usage:
  {{- $liveness := include "openproject.mergedProbe" (dict "probe" .Values.probes.liveness "overrides" .Values.hocuspocus.probes.liveness) | fromYaml }}
*/}}
{{- define "openproject.mergedProbe" -}}
{{- $probe := deepCopy .probe }}
{{- range $key, $value := (.overrides | default dict) }}
{{- $_ := set $probe $key $value }}
{{- end }}
{{- $probe | toYaml }}
{{- end }}
