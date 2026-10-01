# Red Hat Portfolio-Demo auf AWS: Bauanleitung

Stand: 30.09.2026 · Demo-Termin: 02.10.2026 · Build-Start: 30.09.2026, ca. 15:00

Status (01.10.2026, 13:40): Alles gebaut und als Agent getestet: Fundament, ROSA mit GPU (L4),
AAP mit MCP, Portal, GitOps-Plattform, Flotte (ocp19, ocp20, Localnews, Policies), RHOAI 3.5 mit
MaaS (Granite selbst gehostet; Claude Haiku, Sonnet, Opus und GPT-6 Luna extern), Katalog-Items
plus Aufräumen, Demo-Agent über MCP. Alles in der Demo Sichtbare ist englisch (D47). Offen:
Operator-Persona testen (Trockenlauf), Fine-Tuning-Notebook, Demo-Skript, Generalprobe.
Details in `docs/build-journal.md`.

Dieses Dokument ist Spezifikation und Arbeitsanweisung für Agenten zugleich. Die Umgebung wird
mit Claude Code gebaut; wer hier arbeitet, Mensch oder Agent, hält das Dokument aktuell.
Interne Ergänzungen (Publikum, Drehbuch, Account-Details) stehen in `CLAUDE.local.md`, die
nicht im Repo liegt.

---

## 1. Worum es geht

Die Demo zeigt das Red Hat Portfolio an einer lauffähigen Plattform auf AWS. Die Leitidee:
"Serving high-value services on a common foundation and scale through automation".

Sie beantwortet drei Fragen:

1. Wie managen wir Edge und Cloud? ROSA als Hub in AWS, zwei kleine Edge-Cluster (ocp19, ocp20)
   im Lab, Flotte über ACM und GitOps.
2. Welche AI-Fähigkeiten haben wir? OpenShift AI 3.5 mit AI-Namespaces für Engineering, einem
   selbst gehosteten Granite und Models-as-a-Service (MaaS), hinter dem auch ein externes
   Modell hängt (Claude Haiku 4.5 über die Anthropic-API).
3. Wie sehen wir Automatisierung? Terraform für Cloud-Services, Ansible als Orchestrierungs- und
   Execution-Layer, ausdrücklich auch für Agenten, und Argo CD mit YAML in Git für die
   Kubernetes-Ebene.

Die Agenten-Seite zeigen wir live: Claude Code bedient die fertige Plattform über MCP
(AAP-MCP-Server, OpenShift-MCP-Server). Menschen bestellen im Ansible Automation Portal, der
Agent über MCP. Beide landen bei denselben Job-Templates, mit demselben RBAC und demselben
Audit-Trail. Das ist die Kernbotschaft "Ansible als Execution Layer für Agenten".

Und die ganze Umgebung selbst ist mit Claude Code in ein bis zwei Tagen entstanden. Die
Git-Historie, dieses Dokument und `docs/build-journal.md` belegen das.

## 2. Das Zielbild

Das Zielbild stammt von einem Whiteboard, aufgeräumt als Folie (nicht im Repo). Wir lesen es
von unten nach oben. Die rechte Spalte enthält die Notizen, die neben der Folie standen.

| Ebene | Inhalt | Notizen |
|---|---|---|
| Hardware | CPU, GPU, Storage via CSI (S3, Block, File) | |
| OpenShift / Kubernetes | Multi-Cluster, Multi-Tenancy, GPU-fähig, Policies erzwungen | "ROSA", "OpenShift MCP" |
| K8s-aaS | Hosted Control Planes (HyperShift) | "Not required" |
| VM-aaS | OpenShift Virtualization | "Not required" |
| Namespace-aaS | Multi-Tenant-Projekte | "Localnews sample app (helm)" |
| AI Namespace-aaS | OpenShift AI: validierter Modellkatalog, Jupyter, Training, Model- und Agent-Deployment, MCP-Katalog; 1 Develop, 2 Deploy | "Populate with some small samples" |
| Promote | Schritt 3: vom AI-Namespace nach MaaS | |
| MaaS | self-hosted Modelle, API-Key + Endpoint, konform, klein bis groß, OpenAI-kompatibel, vLLM / llm-d | "Self-host a small granite model" |
| Externe Provider | Bedrock, OpenAI usw. über dieselbe API | |
| Zielgruppen | App-Teams, Engineering (eigene Modelle und Agenten), General Purpose (Modelle konsumieren) | |
| Front Door | ServiceNow für Bedarf und Requests | "Should be just mocked"; Katalog: AI-Namespace, Namespace, Model-Endpoint, DBaaS; "I should be able to request an AI namespace; YAML should be generated and put into a git" |
| Automatisierung | Ansible Automation Platform | |
| Agent | "My Agent (Claude Code)" über MCP | "Give me a model API key, url, and model name of a locally hosted model?"; "What is running in my namespace localnews? (openshift mcp)" |
| Flotte | Fleet Manager & GitOps: jeder Cluster, ein Policy-Set, deklariert in Git | "ACM on ROSA", "ArgoCD" |
| Edge / AI Factory | Linux, Windows, K8s oder VMs? | "ocp19", "ocp20" |
| Terraform | | "put into the git repo how it would have been created with Terraform and connect that to the AAP platform" |

So setzen wir das auf AWS um:

| Im Zielbild | Bei uns |
|---|---|
| Ansible Automation Platform | AAP 2.7 containerized auf einer RHEL-VM in EC2, per Terraform erzeugt |
| ServiceNow als Front Door (Mock) | Ansible Automation Portal auf ROSA, verbunden mit dem AAP auf der VM. ServiceNow wird nur erzählt: dieselben Job-Templates lassen sich dahinter hängen |
| DBaaS (Postgres) | Amazon RDS for PostgreSQL, per Terraform, das AAP aufruft |
| Externer Provider | Claude Haiku 4.5 direkt über die Anthropic-API als MaaS `ExternalModel`. Bedrock ist in der Sandbox per Service Control Policy gesperrt |
| ROSA | ROSA HCP, wirklich per Terraform erzeugt |
| Terraform "connect to AAP" | Terraform-CLI (kostenlose Community-Edition), State in S3. AAP ruft Terraform über `cloud.terraform` in einem eigenen Execution Environment auf |
| K8s-aaS, VM-aaS | bauen wir nicht ("Not required") |

## 3. Arbeitsregeln für Agenten in diesem Projekt

- Das Repo `maxisses/portfolio-demo` ist öffentlich. Kein Secret-Wert landet je in Git, auch
  nicht in Beispielen oder Logs. Keine Kundennamen, nirgends. Die AWS-Account-ID ist laut AWS
  kein Secret und darf in IAM-ARNs stehen (D38), sonst nicht.
- Interna stehen in `CLAUDE.local.md` und im Ordner `local/`, beide gitignoriert. Nichts davon
  in öffentliche Dateien, Commits oder Code-Kommentare kopieren. Vor jedem Commit
  `git status` prüfen.
- Secrets liegen lokal in `.env` (gitignoriert). Laden immer mit `source scripts/load-env.sh`.
  Das Skript versteht `KEY=value` und das ältere `KEY: value`. Werte nie ausgeben, bei
  Kontrollen nur Variablennamen zeigen.
- Vor jedem Terraform- oder AWS-Lauf `aws sts get-caller-identity` prüfen: Es muss der
  Sandbox-Account aus `CLAUDE.local.md` sein, nicht das `default`-Profil.
- Alles deklarativ und reproduzierbar: Cloud-Ressourcen per Terraform, Konfiguration und
  Orchestrierung per Ansible, alles im Cluster als YAML in Git, synchronisiert durch Argo CD.
  Kein `oc apply` von Hand. Ausnahmen: der Bootstrap von Argo CD selbst und der manuelle
  ACM-Import der Edge-Cluster (Abschnitt 6.3).
- Manuelle Schritte nur, wo es nicht anders geht (Logins, Subscriptions, Nutzungsbedingungen).
  Jeder davon landet in `docs/manual-steps.md`.
- Externe Repos (ice-demo, Upstream-Charts) nur gepinnt referenzieren, per Commit-SHA oder Tag.
  Versionen generell pinnen, nichts auf `latest`.
- Technology-Preview-Features benennen wir als TP.
- Build-Journal: Nach jedem Arbeitsblock ein Eintrag in `docs/build-journal.md` mit Uhrzeit,
  Dauer, Ergebnis und wer es gemacht hat (Agent oder Mensch). Commits tragen den
  Co-Authored-By-Trailer des Agenten.
- AWS: Region `eu-central-1`. Tags auf allem: `Project=portfolio-demo`, `Owner=mdargatz`,
  `ManagedBy=terraform|ansible`. Namen mit Präfix `portfolio-demo-`.
- Live-Demo ohne Netz: Jede Szene läuft vorher mindestens einmal komplett durch. Was live
  entsteht, bekommt eindeutige Namen, und ein Aufräum-Job-Template entfernt Testbestellungen.
- Der GPU-Machine-Pool bleibt aus, bis Max ihn freigibt (Terraform-Variable
  `gpu_pool_enabled`).
- Fertig heißt verifiziert: Nach jeder Phase die Prüfungen aus Abschnitt 7 ausführen und das
  Ergebnis ins Build-Journal schreiben.

## 4. Umgebung, Ist-Stand (geprüft am 30.09.2026)

### AWS

- RHDP-Sandbox in `eu-central-1` mit öffentlicher Route53-Zone `sandbox3481.opentlc.com`.
  Läuft bis nach dem Demo-Termin. ROSA mit HCP ist per Marketplace aktiviert.
- Beim Start leer: keine VPC (auch keine Default-VPC), keine Instanzen, keine ROSA-Rollen.
- Quotas `eu-central-1`: Standard 1152 vCPU, G/VT 768 vCPU. Keine Anträge nötig.
- GPU-Typen in `eu-central-1`: g5 (A10G 24 GB), g6 (L4 24 GB), g6e (L40S 48 GB).
- Bedrock ist gesperrt: `bedrock:InvokeModel` und `bedrock:InvokeModelWithResponseStream`
  stehen per Service Control Policy auf explizitem Deny, für alle getesteten Modelle und
  Regionen. Auflisten geht, aufrufen nicht. Deshalb Anthropic-API direkt (D28).

### Edge-Cluster

- ocp19 und ocp20 stehen in einem Lab und sind nur im internen Netz erreichbar. Ihre APIs haben
  keine öffentliche DNS-Auflösung. ROSA in AWS erreicht sie also nicht, umgekehrt geht es
  voraussichtlich (ausgehend ins Internet). Das bestimmt die Edge-Architektur (Abschnitt 6.3).
- Offen bis zum Login: Version, installierte Operatoren, ob sie noch an einem anderen ACM-Hub
  hängen.

### Beispiel-Workload Localnews

- Quelle: `https://github.com/maxisses/ice-demo.git`, Chart unter `gitops/helm`, Values
  `values.yaml` plus `values-image.yaml`, gepinnt auf Commit `c4fe2e4`. Das Repo enthält auch
  eine Argo-CD-Application und ein AppProject als Vorlage.
- Der Chart erwartet `clusterDomain` (Apps-Domain des Zielclusters) und nutzt Images von
  `quay.io/k8snativedev`, `quay.io/mdargatz/icedemo` und `postgis/postgis:15-3.4` (Docker Hub).

### Git und Quay

- Git: `git@github.com:maxisses/portfolio-demo.git`, öffentlich, Branch `main`.
- Quay: Namespace `quay.io/mdargatz`, Robot `mdargatz+portfolio-demo`. Repos
  `portfolio-demo-ee` (Execution Environment) und `modelcars` (Granite).

### Lokale Werkzeuge

- terraform 1.16.4, rosa 1.2.65, oc 4.21.17, kubectl, helm, ansible-core 2.19,
  ansible-navigator 26.9, ansible-builder 3.1, podman 6.1, skopeo, git, jq, yq, python 3.11,
  node 26, uv.

## 5. Verifizierte Produktfakten (Stand 30.09.2026)

Gegen die Red Hat Doku geprüft, Links in Abschnitt 12.

OpenShift AI 3.5
- GA, Kanäle `stable-3.5`, `stable-3.x`, `eus-3.5`. Unterstützt OpenShift 4.19.9+, 4.20 und
  4.21, nicht 4.22. ROSA classic und HCP sind unterstützt. Folge: ROSA HCP auf 4.21.
- MaaS-Kern ist GA: API-Keys, Subscriptions mit Token-Limits, externe OIDC-Anmeldung,
  OpenAI-kompatibles Routing über `/v1/chat/completions` mit Modellnamen im Body.
- MaaS als Technology Preview: `ExternalModel`/`ExternalProvider` für externe Anbieter
  (OpenAI, Anthropic, Bedrock; seit 3.4), Bedrock mit STS (3.5), API-Passthrough inkl.
  Anthropic Messages API unter `/v1/messages` (3.5), Multi-Tenancy (3.5),
  Observability-Dashboard (3.4), Loki-Showback (3.5), vLLM-Runtime für MaaS (3.4).
  Dashboard-Schalter `spec.dashboardConfig.externalModels: true` im `OdhDashboardConfig`.
- llm-d ist GA, Istio ist die Gateway-Implementierung (Gateway API).
- MCP Lifecycle Operator (TP, wird mitinstalliert), MCP-Katalog mit Support-Stufen,
  MCP Gateway Operator (TP, separat). OGX (früher Llama Stack): Responses API GA.
- Für CPU-only-Inferenz von LLMs gibt es in 3.5 keinen dokumentierten GA-Weg.

Ansible Automation Platform 2.7
- GA seit 10.06.2026. RPM-Installer entfernt; auf RHEL nur noch containerized (rootless Podman)
  auf RHEL 9.6+ oder RHEL 10.
- Growth-Topologie: alles auf einer VM, mindestens 16 GB RAM, 4 vCPU, 60 GB Disk.
- MCP-Server (TP) läuft auch containerized: Inventory-Gruppe `[ansiblemcp]`, Variablen u. a.
  `mcp_allow_write_operations`. Toolsets: job_management, inventory_management,
  system_monitoring, user_management, security_compliance, platform_configuration,
  content_discovery. Rechte kommen aus dem AAP-RBAC des Nutzers.
- Ansible Automation Portal: auf RHEL nur als VM-Appliance für KVM, OpenShift Virtualization
  und vSphere, kein AWS-Image. Auf OpenShift per Helm-Chart oder Operator. Braucht eine
  OAuth-Application und Tokens im AAP.
- Red Hat positioniert AAP seit Mai 2026 offiziell als "trusted execution layer" für
  agentische IT-Operations.

Terraform und AAP
- Die zertifizierte Integration setzt Terraform Enterprise oder HCP Terraform voraus
  (`hashicorp.terraform`, Provider `ansible/aap`). Nutzen wir nicht.
- Unser Weg: `cloud.terraform` ruft die Terraform-CLI auf. Das Standard-EE enthält aus
  Lizenzgründen kein Terraform-Binary, wir bauen ein eigenes EE. State muss remote liegen
  (Credential-Typ "Terraform backend configuration" in AAP).

ACM und Flotte
- ACM 2.15 unterstützt ROSA HCP als Hub und als Managed Cluster (aktuell sind 2.16/2.17
  dokumentiert; wir nehmen die neueste Version, die OpenShift 4.21 unterstützt).
- Argo CD Pull-Modell: dasselbe ApplicationSet wie beim Push, plus die Annotationen
  `apps.open-cluster-management.io/ocm-managed-cluster`,
  `apps.open-cluster-management.io/pull-to-ocm-managed-cluster` und
  `argocd.argoproj.io/skip-reconcile` im Template. Ziel ist `https://kubernetes.default.svc`,
  verteilt wird per ManifestWork, Status sammelt `MulticlusterApplicationSetReport`.
  War in älteren Versionen TP; Status in der installierten Version beim Bau prüfen.
- Cluster-Proxy-Add-on: Route `cluster-proxy-addon-user` auf dem Hub, damit erreicht man die
  kube-apiserver der Managed Cluster auch hinter einer Firewall (Bearer-Token, z. B. über
  ManagedServiceAccount).
- MCP-Server für OpenShift (TP): standardmäßig read-only, Multi-Cluster über den ACM-Hub mit
  OAuth/OIDC-Token-Exchange (Keycloak).

## 6. Zielarchitektur

```
 Mensch ──► Ansible Automation Portal (ROSA) ──┐
                                               ├──► AAP 2.7 (RHEL-VM) ──► Job-Templates
 Agent (Claude Code) ──► AAP-MCP-Server ───────┘          │
        └──► OpenShift-MCP-Server (read-only) ──► Hub      ├──► Git: generiertes YAML ──► Argo CD ──► Cluster
                                   └─ Cluster-Proxy ─► Edge └──► Terraform-CLI im EE ──► AWS (RDS, Secrets Manager)

 AWS eu-central-1, Fundament per Terraform (einmal lokal gestartet, State in S3)
 ├─ VPC (Single-AZ)
 ├─ ROSA HCP 4.21 "portfolio-hub"
 │   ├─ OpenShift GitOps (Argo CD), ACM-Hub, External Secrets Operator
 │   ├─ Ansible Automation Portal (Helm/Operator)
 │   ├─ OpenShift AI 3.5: AI-Namespaces, MaaS-Gateway, llm-d, Granite
 │   └─ GPU-Machine-Pool (g6e.xlarge, L40S), erst nach Freigabe
 ├─ EC2: RHEL 9.6+ mit AAP 2.7 Growth + MCP-Server (aap.sandbox3481.opentlc.com)
 ├─ S3: Terraform-State · Secrets Manager: Keys und DB-Zugänge
 └─ Route53: *.sandbox3481.opentlc.com

 Anthropic-API ◄── MaaS ExternalModel (Claude Haiku 4.5)

 Lab: ocp19, ocp20 als Managed Cluster
   ├─ Klusterlet verbindet sich ausgehend zum Hub
   └─ lokales Argo CD holt seine Apps selbst von GitHub (Pull-Modell)
```

Henne-Ei beim Fundament: AAP kann seine eigene VM nicht erzeugen. Deshalb starten wir das
Fundament einmal lokal mit der Terraform-CLI. Derselbe Code bekommt danach ein Job-Template in
AAP ("Fundament: terraform plan"), das zeigt, dass AAP auch das Fundament über Terraform fahren
kann.

### 6.1 Service-Katalog

Jedes Item ist ein Job-Template oder Workflow in AAP. Menschen bestellen im Portal, der Agent
über den AAP-MCP-Server. Die AAP-Konfiguration selbst liegt als Code in Git
(`infra.aap_configuration`).

| Item | Eingaben | Was passiert | Ergebnis für den Besteller | Freigabe |
|---|---|---|---|---|
| Namespace | Name, Team, Zielcluster (portfolio-hub, ocp19, ocp20) | AAP rendert YAML (Namespace, RBAC, Quota, Labels) und committet nach `gitops/tenants/<cluster>/`. Argo CD rollt aus, am Edge per Pull | Namespace, Cluster, Console-Link | nein |
| AI-Namespace | Name, Team | Wie Namespace, nur auf portfolio-hub, zusätzlich Data-Science-Projekt, Workbench mit Beispiel-Notebooks, MaaS-Key als `ExternalSecret` | Links zu RHOAI-Dashboard und Workbench | nein |
| Model-Endpoint | Modell (Granite oder Haiku), Team | AAP stellt über die MaaS-API einen Key in der passenden Subscription aus | API-Key, Base-URL, Modellname | nein |
| DBaaS | Name, Größe, Ziel-Namespace (nur portfolio-hub) | Workflow: Freigabe, dann Terraform im EE (RDS for PostgreSQL), Zugang nach Secrets Manager, `ExternalSecret` nach Git | Endpoint, Secret-Name | ja |

Jede erzeugte Ressource trägt die Labels `portfolio-demo/ordered-by` (`portal` oder `agent`) und
`portfolio-demo/request-id` (AAP-Job-ID). So sieht man in jedem Namespace und jedem Commit, ob
ein Mensch oder der Agent bestellt hat. Die Commit-Nachricht nennt Besteller und Kanal.

Localnews ist kein Katalog-Item. Es läuft per ApplicationSet auf den Edge-Clustern und ist der
Beispiel-Workload für die Flotten-Fragen des Agenten.

Vereinfachung für die Demo: Der Model-Endpoint gibt den API-Key im Job-Ergebnis zurück, damit
der Agent ihn sofort nutzen kann. In Produktion käme er über einen Vault oder ein geschütztes
Ticketfeld.

### 6.2 Secrets-Fluss

Kein Secret-Wert in Git. AAP bzw. Terraform schreiben MaaS-Keys, DB-Zugänge und den
Anthropic-Key nach AWS Secrets Manager unter `portfolio-demo/...`. In Git steht nur ein
`ExternalSecret`, das darauf verweist. Der External Secrets Operator auf ROSA liest per
STS/IRSA, also ohne statische AWS-Keys im Cluster.

Die AAP-VM bekommt ein Instance-Profile mit Rechten für RDS, Secrets Manager und den
State-Bucket. IMDSv2 mit Hop-Limit 2, damit die EE-Container die Rolle nutzen können.
Rückfallebene: AWS-Credential in AAP.

### 6.3 Edge-Anbindung

Weil ROSA die Edge-APIs nicht erreicht, fließt alles vom Edge nach außen:

- ACM-Import manuell: Der Hub erzeugt die Import-Manifeste, wir wenden sie von einem Rechner im
  Lab-Netz auf ocp19/20 an. Auto-Import scheidet aus, weil der Hub dafür die Edge-API erreichen
  müsste.
- Policies funktionieren ohnehin im Pull: Der Policy-Controller auf dem Edge holt sie vom Hub.
- GitOps im Pull-Modell: ApplicationSets auf dem Hub mit Pull-Annotationen, OpenShift GitOps
  auf ocp19/20 holt von GitHub. Falls GitOps am Edge fehlt, installieren wir es per ACM-Policy.
- Der Agent fragt die Edge-Cluster über die Cluster-Proxy-Route des Hubs ab und braucht kein
  VPN.
- Der Hub greift nie in den Edge hinein, der Edge holt sich seinen Sollzustand selbst. Das ist
  firewall-freundlich und das richtige Muster für Fabriken und Filialen.

### 6.4 Repo-Struktur

```
CLAUDE.md                  diese Anleitung (öffentlich)
CLAUDE.local.md            Interna, gitignoriert
local/                     interne Unterlagen (Demo-Skript), gitignoriert
README.md                  kurze öffentliche Beschreibung
scripts/                   Hilfsskripte, z. B. load-env.sh
docs/
  build-journal.md         Zeitstempel, Dauer, wer hat was gebaut
  manual-steps.md          alles, was ein Mensch klicken musste
terraform/
  bootstrap/               S3-Bucket für den State (lokaler State, einmalig)
  foundation/              VPC, AAP-VM, Route53, IAM (Instance-Profile, IRSA für ESO)
  rosa/                    ROSA HCP, Machine-Pools (GPU-Pool per Schalter)
  modules/dbaas/           RDS PostgreSQL + Secrets-Manager-Eintrag, von AAP aufgerufen
ansible/
  execution-environment/   EE mit Terraform-Binary und Collections
  inventory/               AAP-Installer-Inventory als Vorlage, ohne Secrets
  playbooks/               aap-install, catalog-*, foundation-plan, cleanup
  templates/               Jinja2-Vorlagen für das generierte YAML
  aap-config/              Config as Code: Organisation, Teams, User, Credentials, Projekte, Job-Templates, Workflow, RBAC
gitops/
  bootstrap/               OpenShift GitOps + Root-Application (einziges manuelles apply, scripts/bootstrap-gitops.sh)
  platform/                App-of-Apps: je Komponente eine Argo-CD-Application (Sync-Waves)
  components/<name>/       Manifeste der Komponenten: acm, cert-manager, connectivity-link, leader-worker-set, nfd, gpu-operator, monitoring, rhoai, ...
  fleet/                   ManagedClusterSets, Placements, GitOpsCluster, Policies
  ai/                      MaaS: Subscriptions, Granite-Deployment, ExternalProvider/Model Anthropic, Samples
  apps/localnews/          ApplicationSet (Pull) auf ice-demo, gepinnt
  tenants/<cluster>/       von AAP generiert, nie von Hand
agent/                     Vorlage für das Demo-Verzeichnis des Agenten (siehe 6.5)
```

### 6.5 Identitäten und der Demo-Agent

- ROSA: htpasswd-IdP mit `admin` (cluster-admin) und `engineer` (normaler Nutzer, Gruppe
  `team-ai`). Passwörter nur in `.env` bzw. Secrets Manager.
- AAP: `admin` (Einrichtung, Freigaben), `max` (bestellt im Portal), `agent-claude` (darf nur
  die vier Katalog-Templates ausführen und lesen). Der AAP-MCP-Server läuft im Schreibmodus;
  was der Agent darf, bestimmt allein das RBAC von `agent-claude`.
- Technische Konten: ServiceAccount für AAP auf dem Hub mit minimalen Rechten (Argo-Status
  lesen, MaaS-Key ausstellen); IRSA-Rolle für ESO; Instance-Profile der AAP-VM.
- Der Demo-Agent läuft nicht im Repo-Verzeichnis. Claude Code liest CLAUDE.md-Dateien auch aus
  übergeordneten Ordnern und würde sonst diese Bauanleitung mitlesen. Ein Skript erzeugt aus
  `agent/` ein eigenes Verzeichnis außerhalb des Repos (z. B. `~/portfolio-demo-agent/`) mit
  eigener CLAUDE.md (Rolle: Entwickler-Agent eines Fachbereichs, nutzt nur die MCP-Tools der
  Plattform, antwortet knapp auf Deutsch), einer `.mcp.json` mit `${AAP_AGENT_TOKEN}`-
  Platzhaltern und einer eigenen Kubeconfig (read-only für Hub, ocp19, ocp20 über
  Cluster-Proxy).

## 7. Bauanleitung

Zeitplan: Mittwochabend Phasen 0 bis 2, Donnerstag Phasen 3 bis 7, Donnerstagabend Phase 8.
Parallel arbeiten, wo es geht: Während ROSA entsteht, installieren wir AAP; während Operatoren
laufen, bauen wir EE und AAP-Konfiguration. Kritischer Pfad: Phase 5 (TP-Features) und Phase 6
(Portal).

### Phase 0: Vorbereitung (ca. 45 min)
- Manuelle Schritte aus Abschnitt 8.
- Werkzeuge, Loader-Skript, Repo-Gerüst, Build-Journal.
- ocp19/20 prüfen: Version, Knoten, installierte Operatoren (GitOps?), vorhandener Klusterlet
  (anderer Hub?), Egress zu `*.openshiftapps.com:443` per Test-Pod.
- Prüfung: `rosa whoami`, `oc whoami` je Edge-Kontext, `terraform version`, `ansible --version`,
  `aws sts get-caller-identity`.

### Phase 1: Fundament per Terraform (ca. 1 h, ROSA läuft im Hintergrund)
- `terraform/bootstrap`: S3-Bucket `portfolio-demo-tfstate-<account-id>` mit Versionierung und
  Verschlüsselung. Locking über `use_lockfile`.
- `terraform/foundation`: VPC Single-AZ mit öffentlichen und privaten Subnetzen (ROSA-Tags),
  NAT-Gateway, EC2 für AAP (RHEL 9.6+ PAYG-AMI von Red Hat, m6i.2xlarge, 120 GB gp3,
  Elastic IP, Security Group 443 offen, 22 nur von der Admin-IP), Route53-Record
  `aap.sandbox3481.opentlc.com`, Instance-Profile für die AAP-VM.
- `terraform/rosa`: Provider `terraform-redhat/rhcs`, Modul `terraform-redhat/rosa-hcp/rhcs`
  (Account-Rollen, Operator-Rollen, OIDC, Cluster `portfolio-hub` 4.21, htpasswd-IdP).
  Standard-Pool 4× m6i.2xlarge (Autoscaling 4-6). GPU-Pool g6e.xlarge (1-2) nur mit
  `gpu_pool_enabled = true`. IRSA-Rolle für ESO.
- Prüfung: `rosa describe cluster -c portfolio-hub` zeigt `ready`, `oc get nodes`, `ssh` auf
  die AAP-VM.

### Phase 2: AAP 2.7 (ca. 1,5 h)
- Playbook `aap-install`: VM vorbereiten, Installer-Bundle kopieren, Inventory rendern
  (Growth-Topologie plus `[ansiblemcp]`, `mcp_allow_write_operations: true`),
  Let's-Encrypt-Zertifikat per Route53-DNS-Challenge, Installer ausführen.
- Subscription in der AAP-Oberfläche aktivieren (manuell).
- EE bauen (Basis `ee-minimal-rhel9`, Terraform-Binary, `cloud.terraform`, `kubernetes.core`,
  `amazon.aws`, `ansible.scm`) und als `quay.io/mdargatz/portfolio-demo-ee` pushen.
- Prüfung: AAP-Oberfläche erreichbar, MCP-Endpunkt antwortet, Test-Job mit dem EE läuft.

### Phase 3: GitOps-Bootstrap und Plattform-Operatoren (ca. 1,5 h)
- `oc apply -k gitops/bootstrap` installiert OpenShift GitOps und die Root-Application.
- Argo CD installiert per Sync-Waves: ACM mit MultiClusterHub, External Secrets Operator mit
  ClusterSecretStore (Secrets Manager über IRSA), NFD und NVIDIA GPU Operator, alle
  Abhängigkeiten von RHOAI 3.5 laut Installationsdoku, RHOAI-Operator mit DataScienceCluster,
  das Ansible Automation Portal.
- Prüfung: alle Argo-Apps `Synced/Healthy`, MultiClusterHub `Running`, DataScienceCluster
  `Ready`.

### Phase 4: Flotte (ca. 1,5 h)
- ocp19/20 manuell importieren (Abschnitt 6.3), Label `env=edge`, Apps-Domain als Label.
  Falls sie noch an einem anderen Hub hängen: erst mit Max klären.
- `ManagedClusterSet`, `Placement` für `env=edge`, `GitOpsCluster`.
- Policy-Set `baseline`: Konsolen-Banner (`ConsoleNotification`) zunächst mit `inform`, dazu ein
  bis zwei harmlose Policies, die compliant sind. Falls GitOps am Edge fehlt: Policy, die es
  installiert.
- Localnews: ApplicationSet im Pull-Modell auf `ice-demo` (`gitops/helm`, gepinnt auf
  `c4fe2e4`), `clusterDomain` aus dem Label des ManagedCluster.
- Prüfung: drei Cluster `Available`, Policy-Status sichtbar, Localnews läuft auf beiden
  Edge-Clustern, Frontend-Route antwortet.

### Phase 5: AI (ca. 2,5 h)
- Granite aus dem validierten AI-Hub-Katalog wählen (passt auf eine L40S mit Luft, kann
  Tool-Calling), ModelCar per `skopeo` nach `quay.io/mdargatz/modelcars` spiegeln.
- GPU-Pool einschalten (erst nach Freigabe durch Max).
- Vorab-AI-Namespace `ai-engineering` mit dem Granite-Deployment (llm-d), veröffentlicht in MaaS.
- MaaS: Subscriptions `standard` (Granite) und `premium` (Granite plus Haiku) mit Token-Limits.
- `ExternalProvider` Anthropic und `ExternalModel` Claude Haiku 4.5, Key aus Secrets Manager
  über ESO, `externalModels: true` im Dashboard.
- AI-Namespace-Vorlage mit Workbench und Beispiel-Notebooks (Chat gegen MaaS, ein Mini-RAG).
- Prüfung: `curl` gegen `/v1/chat/completions` mit einem Key pro Subscription, für beide
  Modelle; Nutzung erscheint im Dashboard.

### Phase 6: Self-Service (ca. 3 h)
- Playbooks für die vier Katalog-Items plus `foundation-plan` und `cleanup`. YAML aus
  Jinja2-Vorlagen, Commit per GitHub-Token, warten bis Argo CD synchron ist, Ergebnis per
  `set_stats` zurückgeben.
- DBaaS als Workflow: Approval-Knoten, `cloud.terraform.terraform` mit
  `terraform/modules/dbaas` und eigenem State-Key pro Bestellung, `ExternalSecret` nach Git.
- AAP-Konfiguration als Code: Organisation, Teams, User, Credentials, Projekt, EE,
  Job-Templates mit Surveys, Workflow, RBAC.
- Ansible Automation Portal an AAP anbinden (OAuth-Application, Token).
- Prüfung: jedes Item einmal über das Portal und einmal über die AAP-API bestellen.

### Phase 7: Agent (ca. 1 h)
- OpenShift-MCP-Server lokal, read-only, mit eigener Kubeconfig (Hub direkt, Edge über
  Cluster-Proxy, jeweils nur `view`).
- AAP-MCP mit Token von `agent-claude`, eingebunden über `.mcp.json` im Demo-Verzeichnis.
- Prüfung: alle Agenten-Szenen laufen ohne Eingriff.

### Phase 8: Generalprobe (Donnerstagabend, ca. 1,5 h)
- Kompletter Durchlauf mit Stoppuhr, danach `cleanup`.
- Am Demo-Morgen: Logins und Tokens erneuern, Smoke-Test, aufräumen.

## 8. Manuelle Schritte für Max

Neue Einträge in `.env` im Format `KEY=value`.

Vor Phase 1:
1. `rosa login --use-device-code` (Red Hat SSO).
2. Red Hat Service Account für den Terraform-Provider `rhcs` (console.redhat.com, Service
   Accounts): `RHCS_CLIENT_ID`, `RHCS_CLIENT_SECRET`.
3. Registry-Service-Account für `registry.redhat.io`: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`.
4. `ANTHROPIC_API_KEY`.
5. GitHub Fine-grained PAT nur für `maxisses/portfolio-demo`, Contents Read and write:
   `GITHUB_TOKEN`.
6. `oc login` auf ocp19 und ocp20.
7. Quay: Repo `portfolio-demo-ee` anlegen (öffentlich), dem Robot Schreibrecht auf
   `portfolio-demo-ee` und `modelcars` geben.

Vor Phase 2:
8. Containerized-Installer-Bundle AAP 2.7 (online) von access.redhat.com herunterladen, Pfad
   als `AAP_INSTALLER_TARBALL`. `AAP_ADMIN_PASSWORD` frei wählen.
9. Nach der Installation: Subscription in der AAP-Oberfläche aktivieren.

Am Demo-Morgen:
10. `oc login` auf ocp19/20 erneuern (Tokens laufen nach 24 h ab), Smoke-Test.

## 9. Entscheidungen

Alle Entscheidungen sind mit Max abgestimmt (Interview in fünf Runden am 30.09.2026).

| ID | Entscheidung | Begründung |
|---|---|---|
| D1 | Region `eu-central-1` | EU-Datenhaltung, GPU-Typen verfügbar |
| D2 | ROSA HCP 4.21, erzeugt per Terraform (`terraform-redhat/rhcs`) | RHOAI 3.5 unterstützt maximal 4.21; Sandbox ist leer |
| D3 | AAP 2.7 containerized, Growth-Topologie, auf RHEL-VM in EC2 | Wunsch; laut Doku unterstützt inkl. MCP-Server |
| D4 | ACM-Hub auf ROSA | Zielbild; ACM unterstützt ROSA HCP als Hub |
| D5 | K8s-aaS und VM-aaS werden nicht gebaut | Zielbild: "Not required" |
| D6 | Granite auf GPU statt CPU | CPU-LLM-Inferenz in RHOAI 3.5 nicht GA |
| D7 | Externes Modell über MaaS `ExternalModel` (TP) | Wunsch; als TP benennen |
| D8 | Demo komplett live, kein Video-Fallback | Runde 1 |
| D9 | Agenten-Story live: Claude Code bedient die Plattform über AAP-MCP und OpenShift-MCP. Kein Agent in der Plattform, Claude Code läuft nicht über MaaS | Runde 1 |
| D10 | Terraform-CLI (Community), State in S3; AAP ruft Terraform über `cloud.terraform` in eigenem EE. Kein HCP Terraform | Runde 1 |
| D11 | Front Door = Ansible Automation Portal auf ROSA, verbunden mit AAP auf der VM. ServiceNow nur erzählt | Runde 1; Portal gibt es nicht als AWS-Image |
| D12 | Die Entstehung mit Claude Code wird erzählt, nicht als Szene gezeigt; Build-Journal läuft mit | Runde 1 |
| D13 | Fundament einmal lokal per Terraform, danach als AAP-Job-Template verfügbar | AAP kann seine eigene VM nicht erzeugen |
| D14 | GPU-Pool g6e.xlarge (L40S, 48 GB), Autoscaling 1-2 | Luft für ein 8B-Modell; Quota vorhanden |
| D15 | Katalog: Namespace (Ziel ROSA/ocp19/ocp20, ohne App), AI-Namespace, Model-Endpoint, DBaaS | Runde 2 |
| D16 | Eigenes Modell = validiertes Granite, als ModelCar in `quay.io/mdargatz/modelcars` | Runde 2 |
| D17 | Einziges externes Modell: Claude Haiku 4.5 | Runde 2; Weg geändert durch D28 |
| D18 | Edge: ACM-Import, Policy-Set, Localnews per ApplicationSet, Flotten-Fragen per Agent. Kein Modell am Edge | Runde 2 |
| D19 | Demo-Teil 45 Minuten | Runde 3 |
| D20 | Freigabe nur für DBaaS (AAP-Workflow mit Approval); die anderen Items laufen durch | Runde 3 |
| D21 | Develop, Deploy, Promote nur erklären; Granite ist vorab in MaaS | Runde 3 |
| D22 | Sandbox läuft bis nach dem Demo-Termin | Runde 3 |
| D23 | ROSA HCP `portfolio-hub`, Single-AZ, 4× m6i.2xlarge (Autoscaling 4-6) | Viele Operatoren auf dem Hub; HCP-Control-Plane ist ohnehin HA |
| D24 | AAP-VM: RHEL 9.6+ PAYG, m6i.2xlarge, 120 GB, `aap.sandbox3481.opentlc.com`, Let's Encrypt | Doppelte Mindestgröße wegen MCP; echtes Zertifikat für MCP und Portal-OAuth |
| D25 | Eigener AAP-User `agent-claude`, Execute nur auf die vier Items, MCP im Schreibmodus | Der Agent darf genau so viel wie ein Mensch mit derselben Rolle |
| D26 | OpenShift-MCP lokal, read-only, eigene Kubeconfig mit view-Rechten | Keycloak-Token-Exchange (TP) ist für 1,5 Tage zu viel |
| D27 | MaaS-Subscriptions `standard` (Granite) und `premium` (Granite plus Haiku) | Tarife und Token-Limits mit wenig Aufwand |
| D28 | Externes Modell direkt über die Anthropic-API statt Bedrock | Runde 4; Bedrock per SCP gesperrt |
| D29 | Reihenfolge der Demo: Agent zuerst | Runde 4 |
| D30 | Localnews aus `maxisses/ice-demo` (`gitops/helm`), gepinnt auf `c4fe2e4` | Chart und Argo-Setup sind dort fertig |
| D31 | Flotten-Moment: Banner-Policy live von `inform` auf `enforce` | Runde 4 |
| D32 | Edge im Pull-Modell: manueller ACM-Import, Argo CD Pull-Integration | Edge-APIs aus AWS nicht erreichbar |
| D33 | Agent erreicht die Edge-Cluster über die Cluster-Proxy-Route des Hubs | Kein VPN nötig |
| D34 | Demo-Agent in eigenem Verzeichnis außerhalb des Repos, eigene CLAUDE.md und `.mcp.json` | Sonst liest der Agent die Bauanleitung mit |
| D35 | Identitäten laut Abschnitt 6.5 | Minimal, zeigt aber RBAC |
| D36 | Interna in `CLAUDE.local.md` und `local/`, beide gitignoriert | Das Repo ist öffentlich und wird gezeigt |
| D37 | GPU-Pool erst nach ausdrücklicher Freigabe durch Max | Runde 5 |
| D38 | AWS-Account-ID in IAM-ARNs im Repo erlaubt (z. B. ClusterSecretStore) | Kein Secret laut AWS; Sandbox ist temporär; die Alternative wäre Templating ohne Mehrwert |
| D40 | AAP-Konfiguration als Code über die REST-API (`ansible/playbooks/aap-configure.yml`), nicht über `infra.aap_configuration` | Die dafür nötigen Collections `ansible.platform`/`ansible.controller` gibt es nur im Automation Hub mit Token |
| D41 | AAP pusht generiertes YAML per GitHub Deploy Key (Schreibrecht nur auf dieses Repo), als Base64-Credential | Enger als ein PAT; `GIT_SSH_COMMAND` darf ein Credential nicht setzen |
| D42 | Katalog-Jobs warten auf den Argo-Sync über die Hub-Application `tenants-<cluster>`; im Pull-Modell meldet ACM den Stand der Edge-Cluster dorthin zurück | Einheitlicher Weg für Hub und Edge, AAP braucht keinen Edge-Zugang |
| D43 | Agent-MCP: AAP `/mcp/job_management` mit Token von `agent-claude`; OpenShift über `kubernetes-mcp-server --read-only --cluster-provider kubeconfig`, Edge über den ACM-Cluster-Proxy mit ManagedServiceAccounts | Kein VPN nötig; Agent sieht per RBAC nur Katalog-Templates |
| D45 | GPU-Pool g6.2xlarge (NVIDIA L4, 24 GB) statt g6e.xlarge; Granite 4.0 H-Tiny FP8 passt mit Luft | AWS meldete InsufficientInstanceCapacity für g6e.xlarge in eu-central-1a |
| D44 | Portal per Helm-Chart `redhat-rhaap-portal` 2.2.10 (OCI-Plugins aus registry.redhat.io), Host `portal.apps.rosa.portfolio-hub...` | Offizieller Weg auf OpenShift |
| D46 | Demo in drei Personas statt Szenen: Developer (Localnews mit MaaS und DBaaS über den Katalog), Platform Operator (Edge-Upgrades orchestrieren, neue Compliance-Vorgabe per Policy), ML Engineer (Fine-Tuning im Notebook, ohne Deploy). Je Persona erst der Ablauf, dann das Architekturbild | Abstimmung mit Max am 01.10. |
| D47 | Alles, was in der Demo sichtbar ist, auf Englisch: Katalog, Surveys, Job-Ausgaben, Commit-Nachrichten von AAP, generiertes YAML, Policies und Banner, MaaS-Namen, Notebooks, Agent-Persona. Bauanleitung, Build-Journal und interne Notizen bleiben deutsch | Wunsch von Max |
| D48 | Portal synchronisiert die Organisation "Portfolio Demo" alle 5 Minuten; Workflows (Datenbank, Edge-Upgrade) erscheinen dort nicht, nur Job-Templates. Workflows bestellt der Agent über MCP oder ein Mensch in AAP | Verhalten des Portal-Plugins 2.2.10 |
| D39 | MaaS nach der Referenz `rh-aiservices-bu/rhoai-maas-guide`: Gateway `maas-default-gateway` mit ROSA-Wildcard-Zertifikat, PostgreSQL im Cluster, Passwort aus Secrets Manager über ESO | In 3.5 liegt MaaS unter `aigateway.modelsAsAService` |

## 10. Offene Punkte (klären wir beim Bau)

- ocp19/20: Hängen sie an einem anderen Hub? Ist OpenShift GitOps installiert? Klappt Egress zu
  `*.openshiftapps.com:443`? Welche OpenShift-Version?
- Welches Granite genau (validierter Katalog in RHOAI 3.5)?
- Wie stellt AAP einen MaaS-Key "für ein Team" aus (ServiceAccount pro Team oder eigene
  Identität)? Gegen die 3.5-Doku klären.
- Konfiguration des `ExternalProvider` für Anthropic (Felder, API-Format).
- Installation des Ansible Automation Portals auf ROSA (Helm oder Operator) und OAuth zur VM.
- Status des Argo-CD-Pull-Modells in der installierten ACM-Version (GA oder TP).
- Soll ein Haiku-Key ebenfalls eine Freigabe brauchen, weil er pro Token kostet? Stand heute:
  nein (D20).

## 11. Risiken

- TP-Features (MaaS ExternalModel, AAP-MCP, OpenShift-MCP, ggf. Argo-Pull) verhalten sich anders
  als dokumentiert. Gegenmittel: Phase 5 und 7 früh am Donnerstag.
- Edge: kein Egress vom Lab zum Hub, oder ein alter Hub hält die Cluster fest. Gegenmittel: in
  Phase 0 prüfen, nicht erst in Phase 4.
- Der AWS-Account muss mit dem Red Hat Konto verknüpft sein, das die Cluster anlegt. Sonst
  scheitert die Cluster-Erzeugung; die Verknüpfung geht nur über die Konsole.
- Viele Operatoren auf einem Hub (ACM, RHOAI, Istio, Kuadrant, GPU, ESO, Portal). Hub
  großzügig dimensionieren, Autoscaling an.
- Live ohne Video-Fallback: Generalprobe am Vorabend, jede Szene vorher einmal komplett,
  realistische Timeouts in den Job-Templates.
- Docker-Hub-Rate-Limits für `postgis/postgis` am Edge. Gegenmittel: Image nach Quay spiegeln
  und per Value überschreiben.
- `cloud.terraform` ist nicht der zertifizierte HashiCorp-Weg. Bei Nachfrage ehrlich auf
  HCP Terraform verweisen.

## 12. Quellen

- RHOAI 3.5 Release Notes: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html-single/release_notes/index
- RHOAI 3.5 Technology Preview: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/release_notes/technology-preview-features_relnotes
- RHOAI Supported Configurations 3.x: https://access.redhat.com/articles/rhoai-supported-configs-3.x
- MaaS in OpenShift AI: https://developers.redhat.com/articles/2025/11/25/introducing-models-service-openshift-ai
- AAP 2.7 What's new: https://developers.redhat.com/articles/2026/06/10/whats-new-red-hat-ansible-automation-platform-2-7
- AAP 2.6 Containerized Installation: https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/containerized_installation/index
- AAP MCP-Server containerized: https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/containerized_installation/deploying-ansible-mcp-server
- AAP als Execution Layer für Agenten: https://www.redhat.com/en/about/press-releases/red-hat-establishes-ansible-automation-platform-trusted-execution-layer-it-operations-agentic-era
- Ansible Automation Portal auf RHEL: https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-con_self_service_rhel_appliances
- Self-Service-Portal auf OpenShift (2.5): https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html-single/installing_self-service_automation_portal/index
- HashiCorp und AAP: https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/getting_started_with_hashicorp_and_ansible_automation_platform/terraform-product
- `cloud.terraform` in AAP: https://github.com/ansible-collections/cloud.terraform/blob/main/docs/docsite/rst/guide_aap.rst
- ACM 2.15 Support Matrix: https://access.redhat.com/articles/7133095
- ACM GitOps (Push/Pull): https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.15/html-single/gitops/index
- Argo CD Pull Controller: https://www.redhat.com/en/blog/introducing-the-argo-cd-application-pull-controller-for-red-hat-advanced-cluster-management
- Cluster-Proxy (OCM): https://open-cluster-management.io/docs/scenarios/pushing-kube-api-requests/
- MCP-Server für OpenShift: https://www.redhat.com/en/blog/model-context-protocol-server-red-hat-openshift-now-available-technology-preview
- OpenShift MCP-Server, User Guide: https://github.com/openshift/openshift-mcp-server/blob/main/docs/openshift/user-guide.md
- Localnews (ice-demo): https://github.com/maxisses/ice-demo
