{{- define "openproject.postgresql.fullname" -}}
{{- printf "%s-database" (include "common.names.fullname" . | trunc 54 | trimSuffix "-") -}}
{{- end -}}

{{- define "openproject.postgresql.secretName" -}}
{{- default (printf "%s-auto-generated" (include "openproject.postgresql.fullname" .)) .Values.postgresql.auth.existingSecret -}}
{{- end -}}

{{- define "openproject.postgresql.image" -}}
{{- $image := .Values.postgresql.image -}}
{{- $registry := coalesce .Values.global.imageRegistry $image.registry -}}
{{- if $image.sha256 -}}
{{ printf "%s/%s@sha256:%s" $registry $image.repository $image.sha256 }}
{{- else -}}
{{ printf "%s/%s:%s" $registry $image.repository $image.tag }}
{{- end -}}
{{- end -}}
