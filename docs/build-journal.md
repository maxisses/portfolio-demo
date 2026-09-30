# Build-Journal

Jeder Arbeitsblock: Uhrzeit, Dauer, Ergebnis, wer (Agent = Claude Code, Mensch = Max).

| Datum | Zeit | Dauer | Wer | Ergebnis |
|---|---|---|---|---|
| 30.09.2026 | 15:00 | 90 min | Agent + Max | Interview in fünf Runden, Zielbild aus der Folie übernommen, Ist-Stand von AWS-Sandbox und Edge-Clustern geprüft, Produktfakten gegen die Doku verifiziert, CLAUDE.md als Bauanleitung geschrieben (37 Entscheidungen) |
| 30.09.2026 | 16:45 | 15 min | Agent | Werkzeuge installiert (terraform 1.16.4, rosa 1.2.65, ansible-core 2.19, ansible-navigator, ansible-builder), Repo-Gerüst, Loader für `.env` |
| 30.09.2026 | 17:00 | 10 min | Agent | Terraform `bootstrap`: S3-Bucket für alle States |
| 30.09.2026 | 17:10 | 20 min | Agent | Terraform `foundation`: VPC (Single-AZ, NAT), AAP-VM (RHEL 9.8, m6i.2xlarge, 120 GB), Elastic IP, `aap.sandbox3481.opentlc.com`, Instance-Rolle; 23 Ressourcen |
| 30.09.2026 | 17:30 | 15 min | Agent | Terraform `rosa` geschrieben und validiert (Modul rosa-hcp 1.7.5, GPU-Pool per Schalter aus); wartet auf Red-Hat-Login |
| 30.09.2026 | 17:45 | 10 min | Agent | Ansible `aap-prepare`: VM vorbereitet, Let's-Encrypt-Zertifikat per Route53-DNS-Challenge über die Instance-Rolle |
| 30.09.2026 | 19:30 | 20 min | Agent | ROSA-Anmeldung: Service-Account-Secret wurde von Red Hat SSO abgelehnt; Terraform nutzt jetzt die `rosa login`-Sitzung (scripts/tf.sh). ROSA HCP 4.21.34 `portfolio-hub` gestartet |
| 30.09.2026 | 19:45 | 20 min | Agent | AAP 2.7: Installer-Inventory (Growth + MCP-Server, Let's-Encrypt-Zertifikat) als Vorlage, Passwörter in Secrets Manager, Installation gestartet; Port 8448 für MCP geöffnet |
| 30.09.2026 | 19:55 | 5 min | Agent | ROSA `portfolio-hub` fertig (36 Ressourcen, ~22 min): 4× m6i.2xlarge, OpenShift 4.21.34 |
| 30.09.2026 | 20:00 | 10 min | Agent | AAP-Installer hing an der DB-Verbindung über die öffentliche IP; Fix als Code: eigener FQDN zeigt auf der VM auf die private IP (`aap-prepare.yml`) |
| 30.09.2026 | 20:05 | 25 min | Agent | GitOps-Bootstrap, App-of-Apps; ACM 2.17, cert-manager, Connectivity Link, LeaderWorkerSet, NFD, GPU Operator, User Workload Monitoring, RHOAI 3.5 per Argo CD |
| 30.09.2026 | 20:15 | 5 min | Agent | AAP 2.7 fertig installiert (Growth + MCP-Server), Gateway und MCP antworten mit Let's-Encrypt-Zertifikat |
| 30.09.2026 | 20:20 | 35 min | Agent | Terraform `platform`: IRSA-Rolle für ESO, MaaS-DB-Passwort. GitOps: External Secrets Operator (Egress-Policy nötig, weil der Operator per Deny-All isoliert), MaaS-Gateway mit ROSA-Wildcard-Zertifikat, PostgreSQL, DataScienceCluster v2. RHOAI 3.5 und MaaS `Ready`, `https://maas.apps.rosa.../maas-api/health` antwortet |
| 30.09.2026 | 21:00 | 5 min | Max + Agent | AAP-Subscription: Manifest (AAP Premium Enablement, bis 24.10.2026) per Playbook über die API aktiviert |
| 30.09.2026 | 21:15 | 15 min | Agent | EE `quay.io/mdargatz/portfolio-demo-ee:1.0.0` auf der AAP-VM gebaut und gepusht |
| 30.09.2026 | 21:30 | 20 min | Agent | Terraform aus AAP planbar gemacht (SSH-Key als Variable, ReadOnly für die VM-Rolle). Dabei Drift gefunden: ROSA-Tag an den Subnetzen war entfernt worden, jetzt im Code; `terraform plan` ohne Änderungen |
| 30.09.2026 | 21:00 | 60 min | Agent + Max | Flotte: ocp20 von Hub isar gelöst und per Pull in ROSA importiert (`Available`). ocp19: kaputtes lokales ACM samt 9134 toten Pods entfernt (scripts/edge-remove-acm.sh), Import angestoßen; Knoten hat DiskPressure, Klusterlet kann nicht starten |
| 30.09.2026 | 22:00 | 30 min | Agent | AAP als Code über die REST-API (Organisation, Nutzer max/agent-claude, Credential-Typ Git Deploy Key, Terraform-State-Credential, EE, Inventory, Projekt). Job-Template "Terraform: Plan (Drift-Check)" läuft in AAP erfolgreich: keine Abweichung zwischen Code und AWS |
| 30.09.2026 | 22:05 | 5 min | Max + Agent | GitHub Deploy Key mit Schreibrecht für AAP (Schlüssel lokal erzeugt, öffentlicher Teil in GitHub) |
