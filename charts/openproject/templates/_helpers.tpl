{{/*
Returns the OpenProject image to be used including the respective registry and image tag.
*/}}
{{- define "openproject.image" -}}
{{ .Values.image.registry }}/{{ .Values.image.repository }}{{ if .Values.image.sha256 }}@sha256:{{ .Values.image.sha256 }}{{ else }}:{{ .Values.image.tag }}{{ end }}
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
  {{- (not .Values.develop) -}}
{{- end -}}
{{- end -}}

{{- define "openproject.tmpVolumeMounts" -}}
{{- if eq (include "openproject.useTmpVolumes" .) "true" }}
- mountPath: /tmp
  name: tmp
- mountPath: /app/tmp
  name: app-tmp
{{- end }}
{{- end -}}

{{- define "openproject.tmpVolumeSpec" -}}
{{- if eq (include "openproject.useTmpVolumes" .) "true" }}
- name: tmp
  # we can't use emptyDir due to the sticky bit issue
  # see: https://github.com/kubernetes/kubernetes/issues/110835
  ephemeral:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.openproject.tmpVolumesStorage }}
- name: app-tmp
  # we can't use emptyDir due to the sticky bit / world writable issue
  # see: https://github.com/kubernetes/kubernetes/issues/110835
  ephemeral:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.openproject.tmpVolumesStorage }}
{{- end }}
{{- end -}}

{{- define "openproject.envFrom" -}}
envFrom:
  - secretRef:
      name: {{ include "common.names.fullname" . }}-core
  {{- if .Values.openproject.oidc.enabled }}
  - secretRef:
      name: {{ include "common.names.fullname" . }}-oidc
  {{- end }}
  {{- if .Values.s3.enabled }}
  - secretRef:
      name: {{ include "common.names.fullname" . }}-s3
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
{{- end }}

{{- define "openproject.env" -}}
env:
  {{- if .Values.egress.tls.rootCA.fileName }}
  - name: SSL_CERT_FILE
    value: "/etc/ssl/certs/custom-ca.pem"
  {{- end }}
  {{- if .Values.postgresql.auth.existingSecret }}
  - name: OPENPROJECT_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ .Values.postgresql.auth.existingSecret }}
        key: {{ .Values.postgresql.auth.secretKeys.userPasswordKey }}
  {{- else if .Values.postgresql.auth.password }}
  - name: OPENPROJECT_DB_PASSWORD
    value: {{ .Values.postgresql.auth.password }}
  {{- else }}
  # {{ required "Database password is required. Please set postgresql.auth.existingSecret (recommended) or postgresql.auth.password" "" }}
  {{- end }}
{{- end }}

{{- define "openproject.envChecksums" }}
# annotate pods with env value checksums so changes trigger re-deployments
{{- $namespace := .Release.Namespace }}
{{- $prefix := include "common.names.fullname" . }}
{{/* If I knew how to map and reduce a range in helm I would do that and use a single checksum. But here we are. */}}
{{- range $suffix := list "core" "memcached" "oidc" "s3" "environment" }}
{{- $secretObj := (lookup "v1" "Secret" $namespace (printf "%s-%s" $prefix $suffix)) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
checksum/env-{{ $suffix }}: {{ values $secretData | sortAlpha | cat | sha256sum }}
{{- end }}
{{- end }}
