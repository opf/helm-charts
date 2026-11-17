{{- define "openproject.proxy.container" -}}
{{- $proxy := .Values.proxy -}}
- name: proxy
  {{- include "openproject.containerSecurityContext" . | nindent 2 }}
  image: "{{ $proxy.image.registry }}/{{ $proxy.image.repository }}{{ if $proxy.image.sha256 }}@sha256:{{ $proxy.image.sha256 }}{{ else }}:{{ $proxy.image.tag }}{{ end }}"
  imagePullPolicy: {{ default .Values.image.imagePullPolicy $proxy.image.imagePullPolicy }}
  command: [caddy]
  args: [run, --config, /etc/caddy/Caddyfile, --adapter, caddyfile]
  env:
    - name: XDG_CONFIG_HOME
      value: /tmp/config
    - name: XDG_DATA_HOME
      value: /tmp/data
    {{- with $proxy.extraEnvVars }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  ports:
    - name: http
      containerPort: {{ $proxy.port }}
      protocol: TCP
  volumeMounts:
    - name: proxy-config
      mountPath: /etc/caddy
      readOnly: true
    - name: proxy-tmp
      mountPath: /tmp
    {{- with $proxy.extraVolumeMounts }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- range $kind := list "liveness" "readiness" }}
  {{- $probe := include "openproject.mergedProbe" (dict "probe" (index $.Values.probes $kind) "overrides" (index $proxy.probes $kind)) | fromYaml }}
  {{- if $probe.enabled }}
  {{ $kind }}Probe:
    tcpSocket:
      port: http
    {{- include "openproject.probeSettings" $probe | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- if $proxy.resources }}
  resources: {{- toYaml $proxy.resources | nindent 4 }}
  {{- else if and (coalesce $proxy.resourcesPreset .Values.resourcesPreset) (ne (coalesce $proxy.resourcesPreset .Values.resourcesPreset) "none") }}
  resources: {{- include "common.resources.preset" (dict "type" (coalesce $proxy.resourcesPreset .Values.resourcesPreset)) | nindent 4 }}
  {{- end }}
{{- end -}}
