# 12. Environment names come from a private Settings repo

Status: Accepted

## Context

The repos go public through a mirror (GATE-12), so they shouldn't name this environment's Azure resources, its SonarQube Cloud project or the repos Renovate updates. Those resources keep their names, since Azure can't rename a resource group or a registry, and someone who clones the kit needs names of their own. A pipeline needs some of these names when it compiles: a container job's image, whose registry connection goes with it, and the pool. Template expressions fill those in, and they see only the variables a pipeline's YAML defines, not those in variable groups or set in the UI.

## Decision

- Settings, a private repo in the project, holds one file, variables.yml, a variables template with the registry's login server, the pool's name, SonarQube Cloud's project key and Renovate's repo list. infra/azdo/settings.tf makes the repo and writes the file, with the registry and the pool from the resources Terraform made, the repo list from the repos it manages, and the key from an input.
- A pipeline that needs a name lists Settings as a repository resource, adds its template to its variables, and reads the name with a template expression, such as `${{ variables.registry }}`. Each such pipeline has an authorization for Settings in settings.tf, since the project protects access to repos from YAML pipelines.
- Terraform builds the Azure resources' names from its workload input, as in rg-<workload>-registry. Pipeline azdo-terraform passes it and the SonarQube key from variable group azdo, which only that pipeline may use, and only from main.
- Contributors can read Settings but can't push to it, so its names change only through Terraform, whose next apply puts back any other change.
- Settings' main has the other repos' one-reviewer policy, since an Only main check verifies that every repo a run reads has a branch policy. The group Settings Writers, whose one member is Terraform's identity, may push past it to write variables.yml.
- Pipeline build-image pushes with Docker@2, whose registry-push connection knows the registry, so its YAML names none.

## Alternatives considered

- A variable group, whose variables a template expression can't see, so it can't set an image or a pool.
- New Azure resources under the kit's names, which would still put an environment's names in public files, and would mean making the registry, the pool, the identities and their connections again.
- The names in the public files, which every clone would have to edit, and which tell anyone which registry and project to look for.
- Runtime parameters, whose defaults would sit in the public YAML.

## Consequences

- A clone of the kit gets its own Settings from its own infra/azdo, with its own resources' names.
- A pipeline that starts reading Settings needs an authorization in settings.tf, or its first run waits for someone to permit it.
- Terraform run by hand asks for its two inputs, unless TF_VAR_workload and TF_VAR_sonar_project_key are set.
- The names still show in the pipelines' runs and logs, which only the project's members can read.
