# 6. The AI developer signs in with workload identities and pushes only its own branches

Status: Accepted

## Context

AI-5 has an AI developer take a user story or bug to a PR with no one watching. It's a Claude Agent SDK program in tools/ai-developer that pipeline ai-developer runs on the project's Managed DevOps Pool. It runs code it writes, since the tests it adds run in dotnet test, so whatever the run can reach, that code can reach too. It has to sign in to Azure DevOps, where a service principal can't have a personal access token, and to the Claude API. It must not be able to push to main, run a pipeline or reach a secret.

## Decision

- It signs in as groundwerk-ai-developer through the ai-developer service connection, of the Azure DevOps type, which uses workload identity federation, so nothing it uses is stored. The pipeline step asks the Azure CLI for two Entra tokens: one for Azure DevOps, which git push and the Azure DevOps MCP server use, and one for the claude-api-audience app registration, which Anthropic's workload identity federation exchanges for Claude API access in the ai-developer Console workspace. That workspace has a $100 monthly spend limit, and the run stops when the credits run out instead of retrying.
- Its permissions come from the AI Developers group: Readers, plus Create branch and Contribute to pull requests on GroundWerk, Contribute denied on main, and Edit work items. A branch's creator gets Contribute on that branch alone, so it pushes only to branches it made. It can't complete a PR into main, so a person completes its PRs.
- Only pipeline ai-developer may use the connection, and only from main. The pipeline has no CI trigger, so a person runs it by hand, and it takes only an item a person has tagged ai-developer.
- Each run gives the agent a fixed list of tools and a hook that lets it push only its item's branch and open only that item's PR. These steer the agent, and the Azure DevOps permissions above are the boundary.
- A push to any branch can start a pipeline with that branch's copy of its YAML, and that copy can add its own triggers. So a pipeline that can reach a secret or a service connection keeps it behind an Only main check. azdo-terraform's service connection already had one, and its HCP token moves from a pipeline variable into the azdo variable group, which gets one too.

## Alternatives considered

- A Claude Console API key in a pipeline secret, which is a stored secret that every run of the pipeline can read, including a run of a branch's copy of its YAML.
- A personal access token for Azure DevOps, which a service principal can't have, and which would be a stored secret too.
- Contribute on the whole repo, which would let it push to anyone's branch, an approved PR's included, and auto-complete would then merge what it pushed, since main's policy keeps approvals after a push.
- Claude Code's own permission prompts, which no one is there to answer.

## Consequences

- Code the agent runs can read both of its tokens. Each lasts about an hour, and the Claude one can spend only what the workspace's limit allows.
- It can still approve other people's PRs, since Contribute to pull requests includes voting, and its approval counts toward main's one-reviewer policy. Making azure-reviewer a required reviewer on main would close this.
- Edit work items is set per area path, and the AI developer's group has it on the project's root area, so it can edit any work item.
- The connection's sign-in can't get new tokens once its 10-minute assertion expires, so the program gets both tokens first. They outlast the step's 45-minute timeout, and a longer run would need the task's keepAzSessionActive option.
- The pool's agents start empty, so each run downloads Claude Code, about 330 MB.
- @azure-devops/mcp 2.11.0 brings packages with high-severity advisories in code it doesn't use here, its interactive sign-in and its HTTP server. The pipeline installs with install scripts off.
- Changing the azdo variable group's variables in Terraform would empty the HCP token, so Terraform ignores them once the group exists.
