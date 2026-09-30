# Red Hat Portfolio-Demo auf AWS

Eine Plattform-Demo, komplett als Code: Terraform für die Cloud-Services, Ansible Automation
Platform als Orchestrierungs- und Execution-Layer (auch für Agenten), Argo CD für alles, was im
Cluster läuft.

- ROSA HCP als Hub mit ACM, OpenShift GitOps und OpenShift AI 3.5 (Models-as-a-Service)
- AAP 2.7 auf einer RHEL-VM mit MCP-Server, davor das Ansible Automation Portal
- Zwei Edge-Cluster, angebunden im Pull-Modell
- Ein Self-Service-Katalog: Namespace, AI-Namespace, Model-Endpoint, DBaaS

Gebaut mit Claude Code. Die Bauanleitung steht in [CLAUDE.md](CLAUDE.md), der Verlauf in
[docs/build-journal.md](docs/build-journal.md).
