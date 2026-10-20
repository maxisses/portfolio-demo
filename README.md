# Red Hat portfolio demo on AWS

A platform demo built entirely as code: Terraform for the cloud services, Ansible Automation
Platform as the orchestration and execution layer (for agents too), and Argo CD for everything
that runs in a cluster. People and AI agents order the same platform services, through the same
job templates, with the same RBAC and the same audit trail.

- ROSA HCP as the hub, with ACM, OpenShift GitOps and OpenShift AI 3.5 (Models-as-a-Service)
- AAP 2.7 on a RHEL VM with its MCP server, fronted by the Ansible Automation Portal
- Two edge clusters ("plants"), connected in the pull model
- A self-service catalog: namespace, AI namespace, model endpoint, database
- Automation orchestrator: an agent diagnoses an outage in a plant, a person approves the fix

The full picture, with components, flows and permissions, is in
[docs/architecture.md](docs/architecture.md).

We built it with Claude Code. The build instructions are in [CLAUDE.md](CLAUDE.md), the history
in [docs/build-journal.md](docs/build-journal.md) (both in German).

Want to build it yourself? [docs/rebuild.md](docs/rebuild.md) covers the prerequisites and a
rebuild from an empty AWS sandbox, also as a fork with your own plant clusters. The orchestrator
part is described in [docs/automation-orchestrator.md](docs/automation-orchestrator.md).
