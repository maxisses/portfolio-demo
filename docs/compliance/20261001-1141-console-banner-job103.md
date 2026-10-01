# Compliance report: console-banner

- Time: 2026-10-01T11:41Z
- Triggered by: ACM PolicyAutomation, run by Ansible Automation Platform (job 103)
- Affected clusters: local-cluster, ocp20

## Violations

- local-cluster: NonCompliant; violation - consolenotifications [portfolio-demo] not found
- ocp20: NonCompliant; violation - consolenotifications [portfolio-demo] not found

## Next step

Review the requirement and switch the policy to `enforce` (gitops/components/fleet).
