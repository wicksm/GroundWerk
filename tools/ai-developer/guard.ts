// Checks the AI developer's tool calls before they run, on top of the allowed-tools list in
// ai-developer.ts, so the agent pushes only its own branch and only opens its PR. Azure DevOps
// permissions are the real boundary, since dotnet test runs code the agent writes (ADR 0006).

export type WorkItemRef = {
  id: string;
  branchPrefix: "story" | "bug";
};

const allowedPush = /^git push (?:(?:-u|--set-upstream) )?origin (\S+)$/;

// The item's branch: story/<id>-<short-name> or bug/<id>-<short-name>
export function branchPattern(item: WorkItemRef): RegExp {
  return new RegExp(`^${item.branchPrefix}/${item.id}-[a-z0-9]+(?:-[a-z0-9]+)*$`);
}

// Says why a tool call is refused, or returns undefined to leave it to the allowed-tools list
export function refusal(toolName: string, input: unknown, item: WorkItemRef): string | undefined {
  const args = typeof input === "object" && input !== null ? (input as Record<string, unknown>) : {};

  if (toolName === "Bash") {
    return checkCommand(typeof args.command === "string" ? args.command : "", item);
  }

  if (toolName === "mcp__ado__repo_pull_request_write") {
    return checkPullRequestWrite(args, item);
  }

  return undefined;
}

// Every part of a chained command that pushes must be the one push allowed
function checkCommand(command: string, item: WorkItemRef): string | undefined {
  for (const part of command.split(/&&|\|\||[;|\n]/)) {
    const trimmed = part.trim();
    if (gitSubcommand(trimmed) !== "push") {
      continue;
    }

    const match = allowedPush.exec(trimmed);
    if (!match || !branchPattern(item).test(match[1])) {
      return `Push only with: git push -u origin ${item.branchPrefix}/${item.id}-<short-name>`;
    }
  }

  return undefined;
}

// The word after git and its options, such as push in "git -C src push"
function gitSubcommand(command: string): string | undefined {
  const words = command.split(/\s+/);
  if (words[0] !== "git") {
    return undefined;
  }

  for (let i = 1; i < words.length; i++) {
    if (words[i] === "-C" || words[i] === "-c") {
      i++;
    } else if (!words[i].startsWith("-")) {
      return words[i];
    }
  }

  return undefined;
}

function checkPullRequestWrite(args: Record<string, unknown>, item: WorkItemRef): string | undefined {
  if (args.action !== "create") {
    return "You may only create your PR. This program adds its reviewer, and a person votes on it and completes it.";
  }

  const source = typeof args.sourceRefName === "string" ? args.sourceRefName.replace(/^refs\/heads\//, "") : "";
  if (!branchPattern(item).test(source)) {
    return `Open the PR from your branch, refs/heads/${item.branchPrefix}/${item.id}-<short-name>.`;
  }

  if (args.targetRefName !== "refs/heads/main") {
    return "Open the PR into refs/heads/main.";
  }

  const workItems = typeof args.workItems === "string" ? args.workItems.split(/\s+/) : [];
  if (!workItems.includes(item.id)) {
    return `Link the PR to work item ${item.id} with workItems "${item.id}".`;
  }

  if (args.forkSourceRepositoryId !== undefined) {
    return "Open the PR from a branch in this repo, not from a fork.";
  }

  return undefined;
}
