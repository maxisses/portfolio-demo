#!/usr/bin/env bash
# Erzeugt das Demo-Verzeichnis des Agenten außerhalb des Repos (sonst läse Claude Code die
# Bauanleitung mit): Rolle (CLAUDE.md), MCP-Konfiguration, read-only-Kubeconfig, Startskript.
#   scripts/agent-setup.sh [zielverzeichnis]      (Standard: ~/portfolio-demo-agent)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:-$HOME/portfolio-demo-agent}"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
hub="oc --kubeconfig $root/local/kubeconfig"
mkdir -p "$dest"; chmod 700 "$dest"
kc="$dest/kubeconfig"; rm -f "$kc"

hub_api="$($hub whoami --show-server)"
proxy="https://$($hub get route cluster-proxy-addon-user -n multicluster-engine -o jsonpath='{.spec.host}')"
add_ctx() { # name server token
  KUBECONFIG="$kc" kubectl config set-cluster "$1" --server="$2" >/dev/null
  KUBECONFIG="$kc" kubectl config set-credentials "agent-viewer@$1" --token="$3" >/dev/null
  KUBECONFIG="$kc" kubectl config set-context "$1" --cluster="$1" --user="agent-viewer@$1" >/dev/null
}
add_ctx portfolio-hub "$hub_api" "$($hub get secret agent-viewer-token -n agent-access -o jsonpath='{.data.token}' | base64 -d)"
for c in ocp19 ocp20; do
  add_ctx "$c" "$proxy/$c" "$($hub get secret agent-viewer -n "$c" -o jsonpath='{.data.token}' | base64 -d)"
done
KUBECONFIG="$kc" kubectl config use-context portfolio-hub >/dev/null
chmod 600 "$kc"

cp "$root/agent/CLAUDE.md" "$dest/CLAUDE.md"
# Token direkt eintragen (Datei liegt außerhalb des Repos, nur für den Nutzer lesbar), damit
# die MCP-Konfiguration auch im Code-Tab der Desktop-App ohne Startskript funktioniert.
token="$(aws secretsmanager get-secret-value --secret-id portfolio-demo/aap/agent-token --query SecretString --output text)"
sed -e "s#__KUBECONFIG__#$kc#" -e "s#\${AAP_AGENT_TOKEN}#$token#" "$root/agent/mcp.json.template" > "$dest/.mcp.json"
chmod 600 "$dest/.mcp.json"
# Projekt-Einstellungen: MCP-Server aus .mcp.json ohne Rückfrage laden, Tool-Aufrufe erlauben.
# Die Grenze zieht die Plattform: agent-claude darf in AAP nur Katalog-Templates starten,
# auf den Clustern nur lesen; Kostenpflichtiges hält an einer Freigabe.
mkdir -p "$dest/.claude"
cat > "$dest/.claude/settings.local.json" <<'SETTINGS'
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["aap", "openshift"],
  "permissions": {
    "allow": ["mcp__aap", "mcp__openshift"]
  }
}
SETTINGS
cat > "$dest/start.sh" <<START
#!/usr/bin/env bash
# Startet Claude Code als Demo-Agent. Das AAP-Token kommt frisch aus AWS Secrets Manager.
cd "\$(dirname "\$0")"
LOAD_ENV_QUIET=1 source "$root/scripts/load-env.sh"
export AAP_AGENT_TOKEN="\$(aws secretsmanager get-secret-value --secret-id portfolio-demo/aap/agent-token --query SecretString --output text)"
# Der Anthropic-Key aus .env gehört MaaS (externes Modell), nicht dem Agenten:
# Claude Code läuft über den normalen Claude-Login.
unset ANTHROPIC_API_KEY
exec claude "\$@"
START
chmod +x "$dest/start.sh"

echo "Demo-Agent eingerichtet in $dest"
for c in portfolio-hub ocp19 ocp20; do
  printf "  %-14s " "$c"; KUBECONFIG="$kc" kubectl --context "$c" --request-timeout=15s get ns default -o name 2>&1 | tr "\n" " " || true; echo
done
