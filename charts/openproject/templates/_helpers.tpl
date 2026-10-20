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
Returns the AnyCable image to be used including registry, tag and optional digest.

If a sha256 digest is provided, we render `image:tag@sha256:digest` (tag is kept for traceability).
*/}}
{{- define "openproject.anycable.image" -}}
{{- $img := .Values.anycable.image -}}
{{- $registry := required "anycable.image.registry is required" $img.registry -}}
{{- $repository := required "anycable.image.repository is required" $img.repository -}}
{{- $tag := required "anycable.image.tag is required" ($img.tag | toString) -}}
{{- if $img.sha256 -}}
{{ $registry }}/{{ $repository }}:{{ $tag }}@sha256:{{ $img.sha256 }}
{{- else -}}
{{ $registry }}/{{ $repository }}:{{ $tag }}
{{- end -}}
{{- end -}}

{{/*
Returns the AnyCable imagePullPolicy with a safe fallback.
*/}}
{{- define "openproject.anycable.imagePullPolicy" -}}
{{- default .Values.image.imagePullPolicy .Values.anycable.image.imagePullPolicy -}}
{{- end -}}

{{/*
Returns the path prefix OpenProject is served under, without a trailing slash (empty when served from the root).
*/}}
{{- define "openproject.relativeUrlRoot" -}}
{{- .Values.openproject.railsRelativeUrlRoot | default "" | trimSuffix "/" -}}
{{- end -}}

{{/*
Return the paths the included AnyCable server serves WebSocket and server-sent events connections on.
The ingress routes them unchanged, so they are the same for the ingress, the AnyCable server and ANYCABLE_WEBSOCKET_URL.
*/}}
{{- define "openproject.anycable.websocketPath" -}}
{{- printf "%s%s" (include "openproject.relativeUrlRoot" .) .Values.anycable.ingress.websocketPath -}}
{{- end -}}

{{- define "openproject.anycable.ssePath" -}}
{{- printf "%s%s" (include "openproject.relativeUrlRoot" .) .Values.anycable.ingress.ssePath -}}
{{- end -}}

{{/*
Returns the name of the secret and the key within it holding the secret shared between OpenProject and AnyCable.
*/}}
{{- define "openproject.anycable.secretKeyRef" -}}
{{- if .Values.openproject.live_updates.auth.existingSecret -}}
name: {{ .Values.openproject.live_updates.auth.existingSecret }}
key: {{ .Values.openproject.live_updates.auth.secretKey }}
{{- else if not .Values.anycable.enabled -}}
{{- fail "openproject.live_updates.auth.existingSecret is required when using an external AnyCable server (anycable.enabled=false)" -}}
{{- else if .Values.anycable.auth.existingSecret -}}
name: {{ .Values.anycable.auth.existingSecret }}
key: {{ .Values.anycable.auth.secretKey }}
{{- else -}}
name: anycable-secret-auto-generated
key: secret
{{- end -}}
{{- end -}}

{{/*
Returns the egress rule allowing the web and worker pods to broadcast live updates to the included AnyCable server.
*/}}
{{- define "openproject.anycable.broadcastEgress" -}}
{{- if .Values.anycable.enabled }}
    # Allow broadcasting live updates to the included AnyCable server
    - ports:
        - port: 2345
      to:
        - podSelector:
            matchLabels: {{- include "common.labels.matchLabels" ( dict "customLabels" .Values.commonLabels "context" . ) | nindent 14 }}
              openproject/process: anycable
{{- end }}
{{- end -}}

{{/*
Returns the environment variables the chart sets for the included AnyCable server.
anycable.extraEnvVars of the same name replace them in anycable-deployment.yaml.
*/}}
{{- define "openproject.anycable.env" -}}
- name: ANYCABLE_HOST
  value: "0.0.0.0"
- name: ANYCABLE_PORT
  value: "2345"
# Served on the same paths as OpenProject's ANYCABLE_WEBSOCKET_URL, as the ingress does not rewrite them
- name: ANYCABLE_PATH
  value: {{ include "openproject.anycable.websocketPath" . | quote }}
- name: ANYCABLE_SSE_PATH
  value: {{ include "openproject.anycable.ssePath" . | quote }}
- name: ANYCABLE_SSE
  value: "true"
- name: ANYCABLE_BROADCAST_ADAPTER
  value: "http"
# Connections and subscriptions are authorized by OpenProject through this endpoint
- name: ANYCABLE_RPC_HOST
  value: {{ printf "http://%s:%v%s/_anycable" (include "common.names.fullname" .) .Values.service.ports.http.port (include "openproject.relativeUrlRoot" .) | quote }}
- name: ANYCABLE_SECRET
  valueFrom:
    secretKeyRef:
      {{- include "openproject.anycable.secretKeyRef" . | nindent 6 }}
{{- if .Values.egress.tls.rootCA.fileName }}
- name: SSL_CERT_FILE
  value: "/etc/ssl/certs/custom-ca.pem"
{{- end }}
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
{{- if .Values.openproject.live_updates.enabled }}
# Shared with the AnyCable server: an external one (openproject.live_updates.auth),
# the included one (anycable.auth), or else the auto generated secret (see secret_anycable.yaml)
- name: ANYCABLE_SECRET
  valueFrom:
    secretKeyRef:
      {{- include "openproject.anycable.secretKeyRef" . | nindent 6 }}
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
