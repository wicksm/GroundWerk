# 5. One build script, run the same way on every machine

Status: Accepted

## Context

A pipeline that keeps its build steps in YAML can only be run by the pipeline, so a build on a dev machine drifts from the one that ships, and a pipeline's failure can't be reproduced locally. The build has to compile, test, pack and publish the same way everywhere, and its versions have to come from git history, so every artifact traces back to its commit.

## Decision

- build.cs at the repo root is the build. .NET 10 runs it as a file-based app, so `dotnet run build.cs` needs only the SDK, on a dev machine and in every pipeline, and a pipeline's YAML only checks out the repo, runs the script and publishes what it leaves in artifacts/.
- Bullseye runs its targets in dependency order: restore, build, test, pack and publish, with default running them all and printing the SDK, the version, the test count and the packages, so two runs can be compared. SimpleExec runs each command and fails its target when the command fails.
- MinVer stamps every project's version from git tags such as v1.2.0, and the SDK adds the commit's hash to the informational version. MinVer needs the whole history and the tags, so pipelines check out with fetchDepth: 0 and fetchTags: true, and the script stops in a shallow clone, which would get the wrong version without a warning.
- The pack target packs only the projects in packageProjects, which is empty, since code that only this repo uses stays a project reference. The publish target publishes the Host and copies the dacpac, since publishing the SQL project would deploy it to a database.
- The script's packages take their versions from Directory.Packages.props, like every other package, so its #:package lines carry none.

## Alternatives considered

- Nuke, whose author stepped back from it in November 2025, or Fallout, the fork that carries it on. Either needs a build project and bootstrap scripts, where Bullseye and SimpleExec are two small libraries used from one file.
- Cake, whose scripts need the Cake tool, or Cake Frosting, which needs a console project.
- Build steps in each pipeline's YAML, which no dev machine can run, or a shell script, which has no targets or dependency order of its own.
- A console project for the build, which `dotnet project convert build.cs` makes if the script outgrows one file.
- Nerdbank.GitVersioning, which keeps the version in a version.json file and counts the commits since it changed, where MinVer needs only tags.

## Consequences

- One command builds everywhere: `dotnet run build.cs`, `dotnet run build.cs -- <target>` to run less, and `dotnet run build.cs -- --list-tree` to see the targets.
- Every pipeline checks out the whole history with its tags, and since a new pipeline's checkout is shallow by default, each one says so in its YAML. A clone without tags would also get the wrong version once releases are tagged, and the script can't tell.
- A release is a tag on main. Until the first, versions read 0.0.0-alpha.0 followed by a count of commits.
- MinVer doesn't set the dacpac's own version, DacVersion, which stays 1.0.0.0 until a deploy needs it set.
- A new output, such as an image or a Helm chart, is a new target, and pipelines only run it.
- The script builds under Directory.Build.props like every project, so the analyzers and warnings as errors cover it too.
