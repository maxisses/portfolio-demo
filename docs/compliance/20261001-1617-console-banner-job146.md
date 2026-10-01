# Compliance report: console-banner

- Time: 2026-10-01T16:17Z
- Triggered by: ACM PolicyAutomation, run by Ansible Automation Platform (job 146)
- Affected clusters: ocp19, ocp20

## Violations

- ocp19: NonCompliant; violation - consolenotifications [portfolio-demo] not found
- ocp20: NonCompliant; violation - consolenotifications [portfolio-demo] not found

## Next step

Review the requirement and switch the policy to `enforce` (gitops/components/fleet).
