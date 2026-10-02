# Compliance report: console-banner

- Time: 2026-10-02T06:58Z
- Triggered by: ACM PolicyAutomation, run by Ansible Automation Platform (job 27)
- Affected clusters: ocp19

## Violations

- ocp19: NonCompliant; template-error; Failed to create policy template: configurationpolicies.policy.open-cluster-management.io "console-banner" is forbidden: cannot set blockOwnerDeletion in this case because cannot find RESTMapping for APIVersion policy.open-cluster-management.io/v1 Kind Policy: no matches for kind "Policy" in version "policy.open-cluster-management.io/v1"

## Next step

Review the requirement and switch the policy to `enforce` (gitops/components/fleet).
