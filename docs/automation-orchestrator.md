# Automation Orchestrator in der Portfolio-Demo

Stand 14.10.2026. Red Hat Ansible Automation Platform automation orchestrator 2026.8 (GA, Add-on zu
AAP 2.7), Operator-Kanal `stable`, Build `v2026.8.1791513611`. Entscheidungen D51 bis D56 in der
CLAUDE.md, Abschnitt 6.6.

## Wozu

Die Story "One more thing" am Ende der Präsentation: Um 02:14 schaltet ein Wartungsfenster in Werk
Berlin (ocp19) eine Segmentierungsregel nach IEC 62443-3-3 SR 5.1 scharf. Sie ist zu streng, die
Werks-App verliert ihre Datenbank. ACM meldet den Ausfall, Ansible sammelt Evidenz, ein Task Agent
auf dem selbst gehosteten Granite sieht im Werk nach und findet den Commit, ein Mensch gibt den Fix
frei, Ansible nimmt den Commit per `git revert` zurück, das Werk holt sich den korrigierten Stand.

Der Satz dazu: Agents investigate and report. People decide. Ansible makes the change.

## Ablauf

```
Werk Berlin (ocp19)
  Policy plant-segmentation (SR 5.1, enforce) legt NetworkPolicy iec62443-zone-boundary in localnews an
  -> news-backend nicht bereit (Readiness prüft Datenbank und location-extractor)
  -> Policy plant-app-health (inform) NonCompliant, Status per Pull am Hub
Hub
  ACM PolicyAutomation plant-app-incident -> AnsibleJob -> AAP "Operations: Report Incident" (acm-automation)
  -> Token per Client Credentials (Service Account plant-alerts) -> Webhook /api/v1/webhooks/plant-incident
Automation Orchestrator, Workflow "Plant incident: diagnose and fix"
  1 trigger         Webhook (cluster, plant, policy, message, source, reported_by, aap_job)
  2 evidence        AAP "Incident: Collect Evidence" (lesend: Policies, erzwungene Objekte, Upgrade,
                    wirksame Git-Änderungen der letzten 24 h mit Diff, Runbook-Notizen)
  3 diagnose        Task Agent: Granite über MaaS (Tier Local), Lese-Werkzeuge über OpenShift-MCP,
                    Antwort nach JSON-Schema (root_cause, recommendation, suspected_commit, confidence, summary)
  4 route           Switch: revert_commit | maintenance | escalate
  5 approve         Freigabe durch max (oder admin), Fenster 2 h, Fallback reject
  6 revert          AAP "Operations: Revert Change" (git revert mit Leitplanken, Freigeber im Commit)
  7 verify          Schleife: 30 s warten, AAP "Incident: Plant Health Check", bis plant-app-health Compliant
  8 record_*        AAP "Operations: Record Incident" (Bericht nach docs/incidents)
```

Gemessen am 13. und 14.10.: Meldung bis Freigabe-Anfrage 35 bis 70 s, Freigabe bis Werk grün
etwa 30 s, Bericht in Git nach gut einer Minute.

## Bausteine im Repo

| Datei | Zweck |
|---|---|
| `gitops/components/automation-orchestrator/` | Operator (clusterweit, Kanal stable, Start-CSV gepinnt), PostgreSQL 15 im Namespace `automation-orchestrator-db`, Secrets per ESO, Instanz `AutomationOrchestrator` |
| `gitops/platform/automation-orchestrator.yaml` | Argo-App, Sync-Welle 5 |
| `gitops/components/orchestrator-mcp/` | OpenShift-MCP für den Diagnose-Schritt: Server read-only, oauth-proxy davor, Kubeconfig per ESO aus den Lese-Tokens des Demo-Agenten, ServiceAccount `orchestrator-diagnose` |
| `gitops/platform/orchestrator-mcp.yaml` | Argo-App, Sync-Welle 6 |
| `gitops/components/fleet/policy-plant-segmentation.yaml` | Die Störung (Grundzustand `disabled: true`), Placement nur Werk Berlin |
| `gitops/components/fleet/policy-plant-app-health.yaml` | Erkennung: `news-backend` in `localnews` hat `readyReplicas: 1` (beide Werke) |
| `gitops/components/fleet-automation/policy-automation-incident.yaml` | ACM startet "Operations: Report Incident", höchstens alle 10 min |
| `gitops/components/aap-integration/serviceaccount.yaml` | AAP darf Policies und ClusterCurators am Hub lesen |
| `gitops/components/ai-models/granite.yaml` | vLLM mit `--enable-auto-tool-choice --tool-call-parser=granite4` |
| `terraform/platform/main.tf` | Passwörter für Datenbank und Admin nach Secrets Manager (`portfolio-demo/orchestrator/db`, `/admin`) |
| `ansible/aap-config/objects.yml` | AAP-Benutzer `orchestrator` (mit E-Mail), "Operations: Report Incident" und vier interne Templates |
| `ansible/playbooks/incident-*.yml` | report, evidence, revert, health, record |
| `ansible/orchestrator-config/objects.yml` | Konfiguration des Orchestrators ohne Secrets |
| `ansible/orchestrator-config/plant-incident.workflow.json` | Der Workflow, Platzhalter `__…_ID__` für instanzabhängige IDs |
| `ansible/playbooks/orchestrator-configure.yml` | Konfiguration per REST-API, idempotent |
| `scripts/incident-inject.sh` | Störung einspielen (`--reset` zum Zurücknehmen) |
| `agent/CLAUDE.md` | Demo-Agent darf Störungen melden, nicht freigeben |

## Aufbau nach einem Neuaufbau der Plattform

Voraussetzungen: Hub mit GitOps-Bootstrap, ESO, MaaS mit Granite, AAP installiert und mit
`aap-configure.yml` konfiguriert, ocp19 und ocp20 importiert (der MCP-Zugang zu den Werken nutzt
die ManagedServiceAccounts aus `gitops/components/agent-access`).

1. `scripts/tf.sh platform apply` erzeugt die Passwörter (läuft im normalen Aufbau mit).
2. Argo CD rollt `automation-orchestrator` und `orchestrator-mcp` mit der Root-App aus. Prüfen:
   - `oc get automationorchestrator orchestrator -n automation-orchestrator` zeigt `Ready=True`
     (Operator, PostgreSQL, Migrationen, dann 10 Pods; etwa 10 Minuten).
   - `oc get pods -n orchestrator-mcp` zeigt `2/2 Running`.
3. AAP-Token für den Orchestrator: `scripts/aap-token.sh orchestrator portfolio-demo/orchestrator/aap-token`.
4. Prüfen, dass die AAP-VM MaaS auflöst: `ssh … 'getent hosts maas.apps.rosa.<domain>'`. Direkt
   nach dem Aufbau merkt sich der VPC-Resolver bis zu 15 min, dass es den Namen noch nicht gab.
5. Konfiguration einspielen (lokal, mit `local/kubeconfig` am Hub angemeldet):
   ```bash
   source scripts/load-env.sh
   export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES no_proxy='*'
   cd ansible && ansible-playbook playbooks/orchestrator-configure.yml
   ```
   Legt an oder aktualisiert: Projekt `plant-operations`, Credentials (AAP-Token, MaaS-Key,
   MCP-Token), Integrationen (AAP, MaaS mit Granite, OpenShift read only mit 7 Lese-Werkzeugen),
   Service Account `plant-alerts` mit Client Credentials (nach `portfolio-demo/orchestrator/webhook`),
   AAP als Identity Provider, Workflow aus Git, veröffentlicht. Der MaaS-Key wird beim ersten Lauf
   über die MaaS-API ausgestellt (`portfolio-demo/orchestrator/maas`, 90 Tage).
6. Max meldet sich einmal am Orchestrator über "Ansible Automation Platform" als `max` an (nicht als
   AAP-admin, siehe Stolpersteine). Danach Schritt 5 noch einmal, damit `max` die Projektrolle
   `project-user` bekommt.
7. Smoke-Test: `scripts/incident-inject.sh`, nach gut einer Minute wartet der Lauf an der Freigabe,
   Diagnose prüfen, freigeben, Berlin wird grün, Bericht in `docs/incidents/`.

`scripts/retarget.sh` stellt Routen (Orchestrator, MCP, cluster-proxy) und Domains in allen
Dateien um; nichts davon ist von Hand nachzuziehen.

## Zugänge

- Orchestrator: `https://orchestrator.apps.rosa.<domain>`, Anmeldung über "Ansible Automation
  Platform" (SSO) als `max`. Lokaler `admin` nur für Konfiguration und Notfälle
  (`scripts/show-credentials.sh` zeigt beide Passwörter).
- Secrets Manager (nur Namen): `portfolio-demo/orchestrator/db`, `/admin` (Terraform),
  `/aap-token` (aap-token.sh), `/maas`, `/webhook` (orchestrator-configure.yml).

## Betrieb in der Vorführung

- Störung: `scripts/incident-inject.sh` zu Beginn der Operator-Story oder direkt vor der Folie.
- Zeigen: ACM (plant-app-health für Berlin NonCompliant), im Orchestrator den Lauf, Schritt
  Diagnose (Modell, Tool Calls ins Werk, Antwort), Freigabe, Revert-Commit, Bericht.
- Nach erfolgreichem Lauf ist kein Reset nötig (der Revert stellt `disabled: true` wieder her).
  Nach Ablehnung oder hängendem Lauf: `scripts/incident-inject.sh --reset`.
- ACM meldet dieselbe Policy höchstens alle 10 min. Zweiter Versuch kurz danach: "Operations:
  Report Incident" in AAP oder über Claude Code starten.

## Stolpersteine aus dem Bau (alle behoben, hier zum Wiedererkennen)

| Symptom | Ursache | Lösung im Repo |
|---|---|---|
| Argo-Sync hängt bei der PVC der Datenbank | gp3 bindet erst mit einem Pod, Pod kam eine Welle später | PVC und Deployment in Welle 2 |
| Migration: `must be owner of extension pgcrypto` | Extension vom Superuser angelegt | Start-Skript legt `pgcrypto` als Rolle `orchestrator` an. Ein schon fehlgeschlagener Migrations-Job muss gelöscht werden, der Operator legt ihn neu an |
| Known Issue: `pg-ca-cert` fehlt bei `sslMode: disable` | Operator-Fehler 2026.8 | Platzhalter-Secret `pg-ca-cert` |
| Evidenz-Job 403 | AAP-Hub-Konto durfte Policies nicht lesen | RBAC in `aap-integration` |
| Workflow-Switch: `Attribute 'output' not found` | Agent-Ausgabe liegt unter `result.content` | Ausdrücke `${diagnose.result.content.…}` |
| Granite erfindet volle SHAs | Evidenz hatte nur Kurz-SHAs | Evidenz mit vollen SHAs, Prompt verbietet Erfinden |
| Granite antwortet mit der Schema-Hülle (`properties: {…}`) | kein striktes Schema | `additionalProperties: false`, Prompt "nicht mit einem JSON-Schema" |
| Granite wählt den Revert vom Vortag | nach mehreren Probeläufen stehen Störung, Revert, Störung im Fenster | Evidenz zeigt nur wirksame Änderungen; Revert-Playbook nimmt nie einen Revert zurück |
| Mit Werkzeugen verliert Granite den Commit | kleines Modell, viel Kontext | Prompt in drei Schritten (nachsehen, abgleichen, antworten). Größeres Modell: nur `llm_model` in `objects.yml` ändern |
| SSO: "This email is already associated with an existing account" | AAP-admin und lokaler Orchestrator-admin haben dieselbe E-Mail | als `max` anmelden; AAP-Benutzer haben eindeutige E-Mails |
| `max` sieht keinen Workflow | alles ist verboten, was nicht erlaubt ist | `project_roles` in `objects.yml`, Playbook nach der ersten Anmeldung erneut |
| MCP: `invalid Host header` | DNS-Rebinding-Schutz des MCP-Servers | oauth-proxy mit `--pass-host-header=false` |
| Manifest `kubeconfig.yaml` fehlt in Git | `.gitignore` enthält `kubeconfig*` | Datei heißt `access.yaml` |
| Granite-Update hängt | Rolling Update braucht eine dritte GPU, der Pool hat zwei | ml-lab-Workbench kurz stoppen (`kubeflow-resource-stopped`), danach Annotation entfernen |
| Playbook bricht unter macOS ab ("worker in a dead state") | Proxy-Lookup im geforkten Python | `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES no_proxy='*'`, bei aap-configure zusätzlich `TF_VAR_admin_cidr` setzen |
| Tool-Liste: `limit` zu groß | API erlaubt höchstens 100 | `?limit=100` |

## Grenzen

- Workflows sind keine Kubernetes-Ressourcen. Der Operator kennt nur die CRD
  `AutomationOrchestrator`; Workflows, Credentials und Rollen liegen in der Datenbank und sind nur
  über die REST-API erreichbar. Git ist die Quelle, das Playbook spielt sie ein. Änderungen im
  Canvas exportieren und in die JSON-Datei übernehmen (Platzhalter wieder einsetzen), sonst
  überschreibt der nächste Neuaufbau sie.
- Der Identity Provider "Ansible Automation Platform" lässt sich in 2026.8 nicht zweimal anlegen
  (Known Issue). Das Playbook legt ihn nur an, wenn er fehlt.
- Offene Freigaben benachrichtigen niemanden; Freigeben heißt in die Oberfläche schauen.
- Die Doku nennt OpenShift Container Platform 4.14 bis 4.22. ROSA und ARO stehen nicht ausdrücklich
  drin; keine Supportzusage ohne Rückfrage.
- Das Add-on ist kostenpflichtig; das Entitlement für die Demo ist zu klären.
