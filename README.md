# Red Hat Portfolio-Demo auf AWS

Eine Plattform-Demo, komplett als Code: Terraform für die Cloud-Services, Ansible Automation
Platform als Orchestrierungs- und Execution-Layer (auch für Agenten), Argo CD für alles, was im
Cluster läuft.

- ROSA HCP als Hub mit ACM, OpenShift GitOps und OpenShift AI 3.5 (Models-as-a-Service)
- AAP 2.7 auf einer RHEL-VM mit MCP-Server, davor das Ansible Automation Portal
- Zwei Edge-Cluster, angebunden im Pull-Modell
- Ein Self-Service-Katalog: Namespace, AI-Namespace, Model-Endpoint, DBaaS

- Automation Orchestrator: ein Agent diagnostiziert eine Störung im Werk, ein Mensch gibt den Fix frei

Gebaut mit Claude Code. Die Bauanleitung steht in [CLAUDE.md](CLAUDE.md), der Verlauf in
[docs/build-journal.md](docs/build-journal.md).

**Selbst aufbauen:** [docs/rebuild.md](docs/rebuild.md) (Voraussetzungen, Aufbau aus einer leeren
AWS-Sandbox, auch als Fork mit eigenen Werks-Clustern). Den Orchestrator-Teil beschreibt
[docs/automation-orchestrator.md](docs/automation-orchestrator.md).
