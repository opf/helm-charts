{{- define "openproject.memcached.fullname" -}}
{{- printf "%s-cache" (include "common.names.fullname" . | trunc 57 | trimSuffix "-") -}}
{{- end -}}

{{- define "openproject.memcached.image" -}}
{{- $image := .Values.memcached.image -}}
{{- $registry := coalesce .Values.global.imageRegistry $image.registry -}}
{{- if $image.sha256 -}}
{{ printf "%s/%s@sha256:%s" $registry $image.repository $image.sha256 }}
{{- else -}}
{{ printf "%s/%s:%s" $registry $image.repository $image.tag }}
{{- end -}}
{{- end -}}
