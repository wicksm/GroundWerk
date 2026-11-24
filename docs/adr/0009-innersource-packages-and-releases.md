# 9. GroundWerk.InnerSource's packages go to their own feed and release by tag

Status: Accepted, amended by ADR 0014, which also publishes each release to nuget.org, restores the packages from there and signs in to the feed only to push

## Context

Every service should set up telemetry, and later auth, the same way, from shared code that any team can change through a PR and that a service takes by version (CODE-3, CODE-11, OBS-1). The GroundWerk.InnerSource repo holds that code, so its packages need a feed, a pipeline that publishes them (CICD-13), and a way for GroundWerk's pipelines, its AI developer and the dev container to restore them. Versions come from git tags through MinVer (docs/adr/0005), as GroundWerk.PipelineTemplates' releases do. SonarQube Cloud's Free plan analyzes only main and PRs into main.

## Decision

- GroundWerk.InnerSource's packages go to innersource, a feed in the project with no upstream sources, which the azdo Terraform makes. A consuming repo's nuget.config maps `GroundWerk.*` to it and every other package to nuget.org, so a package on nuget.org with a GroundWerk name is never restored.
- Pipeline innersource-ci builds GroundWerk.InnerSource from the ci template in GroundWerk.PipelineTemplates, from v1.1.0, which pushes a repo's packages when the repo names its feed. Each PR build pushes them as prereleases named for the PR and the run, such as 1.0.1-pr.12.345.1, so a consumer can try a change before it merges. A person releases by tagging main's merge commit with the next version, such as v1.1.0, and the tag's build pushes 1.1.0. A build of main pushes nothing.
- A tag's build skips SonarQube Cloud's analysis, since main's build analyzed the same commit, and the Free plan would take the tag for a branch, which it doesn't analyze.
- Pipelines sign in to the feed as the project's build service, which has the feed's Feed Publisher role, through the template's NuGetAuthenticate step. The AI developer's pipeline restores before its agent starts and then empties that sign-in's token, so the agent still works only as groundwerk-ai-developer (docs/adr/0006).
- In the dev container, a command that needs the feed hands the Azure Artifacts Credential Provider, a .NET tool in the image, a one-hour token from the Azure CLI's sign-in, through VSS_NUGET_ACCESSTOKEN and VSS_NUGET_URI_PREFIXES, for that command only. NuGet's audit reads vulnerability data only from nuget.org, so a restore needs the feed only for a GroundWerk.InnerSource version the package cache lacks.
- innersource-ci may use registry-pull and sonarqube-cloud, as build-groundwerk does, so ADR 0008's exception to ADR 0006 covers both pipelines.

## Alternatives considered

- A stable version on each merge to main. The pipeline would have to choose each version and push its tag, which needs the build service to create tags in GroundWerk.InnerSource, and every merge would be a release.
- Project references from GroundWerk to GroundWerk.InnerSource's code, which CODE-3 rules out, since a service would take every change at once.
- Upstream sources on the feed, which would also store nuget.org's packages there, in the organization's 2 GiB of free storage.
- A personal access token that each person makes, pastes into their NuGet config and renews by hand.
- The credential provider's own sign-in. The tenant's security defaults block its code sign-in, its browser sign-in needs a display the container doesn't have, and it makes a 90-day personal access token in the person's account.

## Consequences

- Every step after NuGetAuthenticate, including a PR's tests and its packages' build code, can read the build service's token, which can push to the feed. A PR's YAML could reach that token anyway, as ADR 0008 says of the connections, and a person still approves every PR.
- A version can't be replaced once it's in the feed, so a bad release is fixed with the next patch, and a version tag is never moved or deleted.
- Each PR build adds prereleases to the feed, and nothing deletes them yet. A package of about 8 KB leaves the 2 GiB far off.
- A merged change reaches consumers only when someone tags a release.
- The token lives only in that command's environment and expires within the hour, so no personal access token is made and nothing in the container keeps one. A restore that needs a new GroundWerk.InnerSource version fails with 401 until it's run with the token, and an agent in a pipeline, whose identity has no role on the feed, can't fetch one.
