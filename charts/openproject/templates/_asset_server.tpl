{{- define "openproject.assetServer.enabled" -}}
{{- if and .Values.assetServer.enabled .Values.ingress.enabled }}true{{ end -}}
{{- end -}}

{{- define "openproject.assetServer.fullname" -}}
{{- printf "%s-assets" (include "common.names.fullname" . | trunc 56 | trimSuffix "-") -}}
{{- end -}}

{{- define "openproject.assetServer.image" -}}
{{- $image := .Values.assetServer.image -}}
{{- $registry := coalesce .Values.global.imageRegistry $image.registry -}}
{{- if $image.sha256 -}}
{{ printf "%s/%s@sha256:%s" $registry $image.repository $image.sha256 }}
{{- else -}}
{{ printf "%s/%s:%s" $registry $image.repository $image.tag }}
{{- end -}}
{{- end -}}
