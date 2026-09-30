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
