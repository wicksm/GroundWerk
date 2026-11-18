# 11. People take stories to PRs through a Claude Code skill, which codes through a subagent

Status: Accepted

## Context

People work on user stories and bugs every day in Claude Code with the Azure DevOps MCP server, with a developer in the loop (AI-1). Until now each item's steps came as a prompt pasted in by hand, which first said which model and effort to switch to. A project skill is a Markdown file in the repo that Claude Code runs as a slash command, and its frontmatter can set a model and an effort. But the model holds only for the turn that starts the skill: the session's model resumes with the developer's next message, and taking an item to a PR spans many messages. A subagent's frontmatter sets its model and effort for as long as it runs.

## Decision

- `/work-on-user-story <ID>` runs the skill in `.claude/skills/work-on-user-story/SKILL.md`. It reads the user story or bug through the azdo MCP server, makes or finds its branch and sets it Active, plans the change with the developer, has it coded, and opens the PR that AGENTS.md describes, carrying the item's criteria and the choices made. After the PR completes, it deletes the merged local branches, and it closes the item once the developer says the change is checked.
- The skill sets Opus 5.5 at high effort in its frontmatter and hands all coding to the subagent `.claude/agents/story-coder.md`, whose frontmatter sets the same. So the first plan and all the coding run on that model and effort, whichever model the session started on.
- story-coder can read, edit and run commands in the checkout, but it doesn't commit, push or reach Azure DevOps. Every commit, PR and work item change happens in the conversation, where the developer sees it.
- The skill runs only when someone names it, never on Claude's own judgment, since it creates branches and changes work items.

## Alternatives considered

- A pasted prompt for each item, which needs the model and effort switched by hand first and repeats the same steps every time.
- The skill alone, whose model holds only until the developer's first reply.
- The whole skill in a forked subagent, with `context: fork`, which would keep its model to the end but couldn't stop for the developer's answers, since a subagent can't ask questions.
- The model and effort in the repo's .claude/settings.json, which would set them for every session in the repo, whatever it's for.

## Consequences

- The skill's later replies, such as taking the developer's changes to the plan, showing story-coder's report or opening the PR, run on the session's model.
- story-coder starts without the conversation, so the skill hands it the item and the agreed plan, and resumes it with each round of changes.
- The AI developer doesn't use either file, since its program loads no project settings, skills or subagents and runs with no one to plan with (docs/adr/0006).
- Changing the model or effort means changing both files' frontmatter in one PR.
