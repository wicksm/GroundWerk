# 8. The PR build runs in the dev image and gates on SonarQube Cloud and gitleaks

Status: Accepted, amended by ADR 0009, which lets pipeline innersource-ci use registry-pull and sonarqube-cloud too

## Context

Every change to main should be checked the same way before it merges (CICD-1, CICD-10): built and tested by build.cs, scanned for secrets, and held to a quality gate on test coverage and issues (GATE-1, GATE-6). The pre-commit hook can be skipped with --no-verify, so only the PR build can make the secret check binding (docs/adr/0007). Builds should run in the dev container's image (CICD-18), and a container job pulls its image from a registry. ADR 0006 keeps every service connection behind an Only main check, but a PR build runs from the PR's merge, not from main, and the PR's own YAML and tests run in its job.

## Decision

- GroundWerk.PipelineTemplates holds the ci stage, stages/ci.yml, and pipelines extend it at a release tag, so a template change reaches a pipeline only through a PR that moves the tag. Pipeline groundwerk-ci extends it, runs on each change to main, and is main's PR build for any change outside docs and Markdown files.
- The stage is one container job on a Microsoft-hosted agent, in the dev container's image. Pipeline build-image builds that image on each change to it on main and pushes it to crgroundwerk, an Azure Container Registry on the Basic tier, and pipelines pin it by digest, so a new image reaches them only through a PR.
- gitleaks scans each of a PR's commits, or the commit a build of main builds, before anything is built or sent to SonarQube Cloud, so a secret never leaves in an analysis. A finding fails the job.
- build.cs runs inside SonarQube Cloud's analysis and writes Cobertura coverage for it. In a PR build the analysis waits for the quality gate, and a failed gate fails the job. A build of main only reports.
- The registry has two service connections that sign in with workload identity federation, each as a managed identity of its own. registry-push can push, and only pipeline build-image may use it, only from main. registry-pull can only pull.
- SonarQube Cloud's token belongs to sonarqube-ci, an Entra ID user that exists only for CI, with Execute Analysis on GroundWerk, and lasts 90 days. It sits in the sonarqube-cloud service connection, made by hand so the token never reaches Terraform's state.
- registry-pull and sonarqube-cloud have no Only main check, since PR builds need them. They are the one exception to ADR 0006, and only pipeline groundwerk-ci may use them.

## Alternatives considered

- A SonarQube Cloud organization token limited to analysis, which needs the Team or Enterprise plan.
- A teammate's or the organization owner's token, which puts a person's key in CI and breaks when they leave. The owner's could also change or delete the organization's projects and settings.
- Building with the hosted agent's own tools, which differ from the dev container's.
- The pre-commit hook alone, which --no-verify skips.
- A registry identity with a client secret, which is a stored secret to rotate.

## Consequences

- A PR's YAML and tests run in its build, so they can use both connections: pull from the registry, and as sonarqube-ci send analyses, read GroundWerk's code in SonarQube Cloud and mark its findings accepted or false positive, which every member can do on the Free plan. The PR still needs a person's approval.
- sonarqube-ci's token expires after 90 days, and so does the Azure DevOps token SonarQube Cloud uses to decorate PRs, so each needs a new one before then.
- SonarQube Cloud's scanner turns warnings-as-errors off while it builds, so a compiler warning doesn't fail the PR build. build.cs on a dev machine still fails on one.
- Coverage counts only the assemblies a test loads, so code in a project that no test uses goes unmeasured.
- A template change needs a new tag and a PR that moves each pipeline to it, and a new image needs a PR that moves each pipeline to its digest.
- Each run pulls the image, about 1.4 GB compressed.
- SonarQube Cloud's automatic analysis stays off, since a pipeline's analysis fails while it's on.
