# Manuelle Schritte

Alles, was ein Mensch klicken oder eintippen musste, weil es nicht als Code geht.

| Datum | Wer | Schritt | Warum nicht als Code |
|---|---|---|---|
| 30.09.2026 | Max | AAP-Manifest auf console.redhat.com besorgt | Download nur mit Red-Hat-Login |
| 30.09.2026 | Max | Tokens für ocp19/ocp20 bereitgestellt (VPN) | Lab-Cluster nur im internen Netz |
| 30.09.2026 | Max | Freigabe: ocp20 von Hub isar lösen, ACM auf ocp19 entfernen | Eingriff in Lab-Infrastruktur |
| 30.09.2026 | Max | GitHub Deploy Key eingetragen | nur über GitHub-Oberfläche |
| 30.09.2026 | Max | ocp19-Disk auf 150 GB vergrößert, Neustart | Lab-Virtualisierung |
| 30.09.2026 | Max | `claude /login` im Terminal für den Demo-Agenten | Anmeldung am eigenen Claude-Konto |
| 01.10.2026 | Agent | Kuadrant-Operator-Pod neu gestartet, nachdem der Gateway-API-Provider bereit war | Bekanntes Verhalten laut MaaS-Referenz: Kuadrant erkennt Istio erst nach Neustart |
| 13.10.2026 | Max | Neue Sandbox: ROSA im AWS-Marketplace aktiviert und den AWS-Account auf console.redhat.com mit der Red-Hat-Organisation verknüpft (Billing-Link) | Nur über AWS- und Red-Hat-Konsole |
| 13.10.2026 | Max | `rosa login --use-device-code`, `oc login` auf ocp19 und ocp20 | Red-Hat-SSO; Lab-Cluster nur im internen Netz |
| 13.10.2026 | Agent | `rosa create ocm-role` und `rosa create user-role` (`--mode auto`) im neuen Account | Verknüpft AWS-Rollen mit der Red-Hat-Organisation; kein Terraform-Weg im verwendeten Modul |
| 13.10.2026 | Agent | PVC und Pods der Portal-Datenbank gelöscht | Datenbank war mit einem Passwort initialisiert, bevor das Secret aus Secrets Manager da war |
| 13.10.2026 | Max | Erste Anmeldung am Automation Orchestrator über "Ansible Automation Platform" (SSO) als `max`, damit der Benutzer für Freigaben existiert | Anmeldung im Browser |
| 13.10.2026 | Max | Vor jeder Vorführung der Orchestrator-Story: `scripts/incident-inject.sh` (spielt die Störung in Werk Berlin per Commit ein) | Teil der Vorführung |
