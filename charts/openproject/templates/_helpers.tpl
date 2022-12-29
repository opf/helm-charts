
{{/*
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "openproject.postgresql.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) -}}
{{- end -}}

{{/*
Return the database hostname
*/}}
{{- define "openproject.databaseHost" -}}
{{- ternary (include "openproject.postgresql.fullname" .) .Values.externalDatabase.host .Values.postgresql.enabled  -}}
{{- end }}

{{/*
Return the Database port
*/}}
{{- define "openproject.databasePort" -}}
{{- ternary "5432" .Values.externalDatabase.port .Values.postgresql.enabled -}}
{{- end -}}

{{/*
Return the Database database name
*/}}
{{- define "openproject.databaseName" -}}
{{- if .Values.postgresql.enabled }}
    {{- .Values.postgresql.auth.database -}}
{{- else -}}
    {{- .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database user
*/}}
{{- define "openproject.databaseUser" -}}
{{- if .Values.postgresql.enabled -}}
    {{- .Values.postgresql.auth.username -}}
{{- else -}}
    {{- .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the Secret name which contains the Database password
*/}}
{{- define "openproject.databasePassword" -}}
{{- if .Values.postgresql.enabled -}}
    {{- .Values.postgresql.auth.password -}}
{{- else -}}
    {{- .Values.externalDatabase.password -}}
{{- end -}}
{{- end -}}
