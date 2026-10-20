# Neuaufbau aus einer leeren AWS-Sandbox

Stand 20.10.2026. Grundlage sind drei vollständige Aufbauten (30.09., 02.10., 13.10.2026); der
letzte dauerte gut zweieinhalb Stunden, davon rund 40 Minuten Warten auf die Verknüpfung von
AWS-Account und Red-Hat-Organisation. Diese Anleitung richtet sich an Menschen und an Agenten.
Ein Agent arbeitet sie mit der [CLAUDE.md](../CLAUDE.md) als Regelwerk ab; die Stolpersteine
der bisherigen Läufe stehen in [build-journal.md](build-journal.md), der Orchestrator-Teil
ausführlich in [automation-orchestrator.md](automation-orchestrator.md).

## 1. Voraussetzungen

Diese Dinge kann kein Agent besorgen. Am besten liegen sie alle bereit, bevor der Aufbau beginnt.

| Was | Wofür | Wo es hinkommt |
|---|---|---|
| AWS-Sandbox (RHDP "Open Environment", `eu-central-1`) mit öffentlicher Route53-Zone und ROSA-Freischaltung im Marketplace | Fundament, ROSA | `.env`: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| Red-Hat-Konto mit Rechten zum Anlegen von ROSA-Clustern | ROSA | `rosa login --use-device-code` |
| Registry-Service-Account für `registry.redhat.io` | AAP-Installer, Operator-Images, Pinning per skopeo | `.env`: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` |
| AAP 2.7 Containerized-Installer-Bundle (online) | AAP auf der VM | `.env`: `AAP_INSTALLER_TARBALL` (Pfad) |
| AAP-Subscription-Manifest (zip) | Lizenz in AAP | `local/aap-manifest.zip` |
| Entitlement für das Add-on Automation Orchestrator | "One more thing" | klären, bevor es gezeigt wird |
| Fork dieses Repos auf GitHub, öffentlich | Argo CD und AAP lesen und schreiben das Repo | `scripts/retarget.sh --repo <owner>/portfolio-demo` |
| Deploy Key mit Schreibrecht auf den Fork | AAP committet generiertes YAML (D41) | privater Teil `local/github-deploy-key`, öffentlicher im Fork unter Settings, Deploy keys |
| SSH-Schlüsselpaar für die AAP-VM | Installation per Ansible | `~/.ssh/portfolio-demo` und `.pub` |
| Zwei OpenShift-Cluster als "Werke" (4.20 bis 4.22), mit ausgehendem HTTPS ins Internet | Flotte, Edge-Stories | `oc login` auf beiden, Import unter den Namen `ocp19` und `ocp20` |
| Anthropic- und OpenAI-Key (optional) | externe Modelle hinter MaaS | `.env`: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` |
| E-Mail für Let's Encrypt | Zertifikat der AAP-VM | `.env`: `LETSENCRYPT_EMAIL` |

Die Images liegen öffentlich auf Quay (`quay.io/mdargatz/portfolio-demo-ee`, `modelcars`,
`icedemo`) und müssen nicht neu gebaut werden. Die Werks-Cluster heißen im Hub immer `ocp19`
(Werk Berlin) und `ocp20` (Werk Mülheim), egal wie sie wirklich heißen: Der Name entsteht beim
Import. Ihre Apps-Domain liest `scripts/edge-import.sh` aus dem Cluster und setzt sie als Label
`apps-domain`; Hostnamen der Werke stehen nirgends im Repo.

Werkzeuge lokal: terraform, rosa, oc, helm, ansible-core 2.19, skopeo, jq, yq, python 3.11
(Versionen in CLAUDE.md, Abschnitt 4). Unter macOS vor jedem `ansible-playbook`:
`export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES no_proxy='*'`.

## 2. Aufbau

Vor jedem Terraform- oder AWS-Schritt `aws sts get-caller-identity` prüfen. Secrets immer mit
`source scripts/load-env.sh` laden und nie ausgeben.

### 2.1 Umstellen (5 min)

1. Fork: `scripts/retarget.sh --repo <owner>/portfolio-demo`.
2. Sandbox: `scripts/retarget.sh --domain sandboxNNNN.opentlc.com --account <aws-account-id>`.
   Das Skript liest die bisherigen Werte aus dem Repo und ersetzt sie überall (auch in der
   lokalen Präsentation, falls vorhanden). Committen, pushen.
3. Lokalen State einer früheren Sandbox wegräumen: `terraform/bootstrap/terraform.tfstate`,
   `local/kubeconfig*`, `rm -rf terraform/*/.terraform`.

### 2.2 Red Hat und AWS verknüpfen (Mensch, 5 min plus Wartezeit)

1. AWS-Konsole, ROSA, "Verify ROSA prerequisites": ROSA aktivieren, dann "Continue to Red Hat"
   und mit **demselben** Red-Hat-Konto verknüpfen, das später `rosa login` nutzt (privates
   Browserfenster, damit kein anderer Login dazwischenfunkt).
2. `rosa login --use-device-code`. Die Sitzung läuft nach einigen Tagen ab; Terraform braucht
   sie auch zum **Abbauen**.
3. Mit geladener `.env`: `rosa create ocm-role --mode auto --yes` und
   `rosa create user-role --mode auto --yes`.
4. Bis OCM den Account als Billing-Account kennt, vergingen am 13.10. rund 40 Minuten. Solange
   scheitert die Cluster-Erzeugung mit "billing account … not linked". Fundament und AAP
   laufen in der Zeit schon.

### 2.3 Fundament und AAP (60 min, parallel zu ROSA)

1. `scripts/tf.sh bootstrap apply`, dann `scripts/tf.sh foundation apply` (VPC, NAT, AAP-VM, DNS, IAM).
2. AAP installieren:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.yml playbooks/aap-prepare.yml
   ansible-playbook -i inventory/hosts.yml playbooks/aap-install.yml
   AAP_MANIFEST=$PWD/../local/aap-manifest.zip ansible-playbook playbooks/aap-license.yml
   ```

### 2.4 ROSA und Plattform (45 min)

1. `scripts/tf.sh rosa apply -auto-approve` (Cluster rund 20 min, dazu Worker- und GPU-Pool).
   GPU-Quota der Sandbox vorher prüfen (Service Quotas, "Running On-Demand G and VT instances").
2. `scripts/tf.sh platform apply` (IRSA für ESO, Passwörter für MaaS und Orchestrator).
3. Clusterdaten übernehmen: `scripts/retarget.sh --cluster portfolio-hub2 --rosa-base <xxxx.p3>
   --infra-id <cluster-id>` (aus den Terraform-Outputs), dann `scripts/tf.sh foundation apply`
   (Subnetz-Tags), committen, pushen.
4. `KUBECONFIG=local/kubeconfig scripts/hub-login.sh` (der htpasswd-Login braucht nach dem
   Cluster ein paar Minuten), dann `scripts/bootstrap-gitops.sh`.
5. Argo CD rollt rund 30 Apps aus. Beobachten mit `oc get applications.argoproj.io -n
   openshift-gitops` (nach der ACM-Installation meint `applications` die ACM-Ressource). Hängt
   eine App an fehlenden CRDs, die Operation entfernen und neu syncen.

### 2.5 AAP verdrahten, Werke, Katalog (30 min)

1. AAP-Konfiguration und Portal (unter macOS zusätzlich
   `TF_VAR_admin_cidr=$(curl -s https://checkip.amazonaws.com)/32` setzen):
   `ansible-playbook playbooks/aap-configure.yml`, dann `playbooks/portal-aap.yml`.
2. Tokens: `scripts/aap-token.sh acm-automation portfolio-demo/aap/acm-token json`,
   `scripts/aap-token.sh agent-claude portfolio-demo/aap/agent-token`,
   `scripts/aap-token.sh orchestrator portfolio-demo/orchestrator/aap-token`.
3. ExternalSecrets anstoßen (Annotation `force-sync` auf alle `externalsecrets.external-secrets.io`).
4. Werke importieren: Edge-Kubeconfig `local/kubeconfig-edge` mit den Kontexten `ocp19` und
   `ocp20`, dann `scripts/edge-import.sh ocp19` und `scripts/edge-import.sh ocp20`.
5. Portal: Startet `redhat-rhaap-portal` nicht (Passwortfehler der Datenbank), PVC und Pods der
   Portal-Datenbank löschen.
6. Warten, bis die AAP-VM `maas.apps.rosa.<domain>` auflöst. Der VPC-Resolver merkt sich bis zu
   15 min, dass es den Namen beim ersten Versuch noch nicht gab, und solange scheitern MaaS-Keys
   in den Katalog-Jobs.
7. Beispiel-Bestellungen: Namespace `radar`, Datenbank `projects` (Workflow mit Freigabe) und
   "Catalog: Deploy App (Localnews)" mit AI; "Catalog: AI Namespace" `ml-lab` mit GPU.
8. Demo-Agent: `scripts/agent-setup.sh`, gestartet wird er mit `~/portfolio-demo-agent/start.sh`.

### 2.6 Automation Orchestrator (20 min)

Siehe [automation-orchestrator.md](automation-orchestrator.md), Abschnitt "Aufbau": Instanz
`Ready` abwarten, `ansible-playbook playbooks/orchestrator-configure.yml`, einmal als `max` über
AAP anmelden, Playbook erneut, Smoke-Test mit `scripts/incident-inject.sh`.

### 2.7 Prüfen

- Alle Argo-Apps `Synced/Healthy` (die Edge-Apps zeigen im Pull-Modell kurz `Progressing`).
- `oc get managedclusters`: drei Cluster `Available`.
- Granite antwortet über MaaS; Localnews läuft auf beiden Werken, und die Routen nutzen die
  richtige Apps-Domain (seit 20.10. kommt sie aus dem Label, beim ersten Aufbau danach besonders
  prüfen).
- Katalog-Bestellung als `agent-claude` über MCP; Incident-Durchlauf im Orchestrator.

## 3. Betrieb

- Nach einer Pause der Sandbox kommen EC2 und RDS von selbst hoch, der Hub nach rund 15 min.
  MaaS antwortet danach mit 503 (`wasm_fail_stream` im Gateway-Log): den Gateway-Pod
  `maas-default-gateway` in `openshift-ingress` neu starten.
- Der GPU-Pool hat zwei L4: eine für Granite, eine für eine GPU-Workbench. Ein Rolling Update
  von Granite braucht kurz eine dritte; die Workbench dafür vorher stoppen.
- `oc login`-Tokens der Werke laufen nach 24 h ab; die Plattform selbst braucht sie nicht, nur
  `edge-import.sh`.

## 4. Abbau

1. Vorher prüfen: `rosa whoami` (gültige Sitzung), `aws sts get-caller-identity`.
2. AAP "Operations: Clean Up Catalog" mit `keep=""`: zerstört bestellte Datenbanken per
   Terraform und entfernt die Tenants aus Git.
3. `scripts/tf.sh platform destroy`, `scripts/tf.sh rosa destroy`.
4. `scripts/tf.sh foundation destroy`. Scheitert die VPC an einer leeren Security Group
   `<cluster-id>-vpce-private-router`, diese löschen und den Schritt wiederholen.
5. `scripts/tf.sh bootstrap destroy`.
6. Optional: `rosa delete ocm-role` und `rosa delete user-role`; Secrets in Secrets Manager, die
   nicht aus Terraform stammen (`portfolio-demo/aap/*`, `/portal/*`, `/orchestrator/aap-token`,
   `/maas`, `/webhook`).
