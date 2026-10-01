{{- define "localnews.labels" -}}
app.kubernetes.io/part-of: localnews
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
