import assert from "node:assert/strict";
import { test } from "node:test";
import { refusal } from "./guard.ts";
import type { WorkItemRef } from "./guard.ts";

const story: WorkItemRef = { id: "61", branchPrefix: "story" };

const pullRequest = {
  action: "create",
  sourceRefName: "refs/heads/story/61-trim-role",
  targetRefName: "refs/heads/main",
  workItems: "61",
};

test("allows pushing the item's own branch", () => {
  assert.equal(refusal("Bash", { command: "git push -u origin story/61-trim-role" }, story), undefined);
  assert.equal(refusal("Bash", { command: "git add -A && git commit -m \"Trim the role #61\" && git push origin story/61-trim-role" }, story), undefined);
});

test("refuses any other push", () => {
  for (const command of [
    "git push origin main",
    "git push origin story/61-trim-role:main",
    "git push origin HEAD:refs/heads/main",
    "git push --force origin story/61-trim-role",
    "git push -u origin story/61-trim-role --force",
    "git push origin --delete story/61-trim-role",
    "git push origin story/62-other-story",
    "git push origin bug/61-trim-role",
    "git push",
    "git -C . push origin main",
    "git status && git push origin main",
  ]) {
    assert.ok(refusal("Bash", { command }, story), command);
  }
});

test("leaves other commands to the allowed-tools list", () => {
  assert.equal(refusal("Bash", { command: "dotnet test --solution GroundWerk.slnx" }, story), undefined);
  assert.equal(refusal("Bash", { command: "git commit -m \"Push the trim into the parser #61\"" }, story), undefined);
  assert.equal(refusal("Bash", { command: "git commit -m \"push the trim into the parser #61\"" }, story), undefined);
  assert.equal(refusal("Read", { file_path: "AGENTS.md" }, story), undefined);
});

test("allows creating the item's PR", () => {
  assert.equal(refusal("mcp__ado__repo_pull_request_write", pullRequest, story), undefined);
});

test("refuses votes, reviewers, auto-complete and other PRs", () => {
  for (const args of [
    { action: "vote", vote: "Approved", pullRequestId: 7 },
    { action: "update", autoComplete: true, pullRequestId: 7 },
    { action: "update", status: "Abandoned", pullRequestId: 7 },
    { action: "update_reviewers", reviewerAction: "add", pullRequestId: 7 },
    { action: "update_reviewers", reviewerAction: "remove", pullRequestId: 7 },
    { ...pullRequest, sourceRefName: "refs/heads/story/62-other-story" },
    { ...pullRequest, targetRefName: "refs/heads/release" },
    { ...pullRequest, workItems: "62" },
    { ...pullRequest, forkSourceRepositoryId: "elsewhere" },
  ]) {
    assert.ok(refusal("mcp__ado__repo_pull_request_write", args, story), JSON.stringify(args));
  }
});
