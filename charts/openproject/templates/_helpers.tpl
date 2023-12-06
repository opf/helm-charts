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
{{- if not .Values.develop -}}
  {{- true -}}
{{- end -}}
{{- end -}}
