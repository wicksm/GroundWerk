# GroundWerk's one image: VS Code's dev container on the dev VM, and the image the pipelines'
# container jobs run in, so a local build uses the same tools as the pipeline (docs/adr/0007).
# It's built for x64 only, as the dev VM and the build agents are. It stays root with no
# ENTRYPOINT, since a container job's agent adds its own user with groupadd and useradd before
# it runs any step, and VS Code signs in to the dev container as ubuntu (devcontainer.json).
# Every tool is pinned, and each one downloaded here is checked against the SHA-256 its
# publisher lists, so to move a tool to a new version, change its version and checksum together.

# Microsoft's .NET 10 SDK image on Ubuntu 24.04. The digest pins the exact image behind the tag.
FROM mcr.microsoft.com/dotnet/sdk:10.0.404-noble@sha256:fe0fd4e93bd2fbb47c883b7a6369e5c8d3db8bf01cdc5981f6ee35fbdf3ff4fb

# Each RUN fails if any command in a pipe fails.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The base image tells every ASP.NET Core app to listen on port 8080. The AppHost gives api, jobs
# and the dashboard their own ports, so this empties that setting, which would otherwise make
# each of them log a warning that it's overriding it.
ENV ASPNETCORE_HTTP_PORTS=

# ssh for git over SSH to Azure Repos, and less as git's pager.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client less \
    && rm -rf /var/lib/apt/lists/*

# The Azure CLI, and the Docker CLI that devcontainer.json's docker-outside-of-docker feature
# connects to the dev VM's Docker. The feature installs a CLI only when there's none, so this one
# keeps the version pinned. Each repository's signing key is checked before apt trusts it.
ARG AZURE_CLI_VERSION=2.92.0-1~noble
ARG DOCKER_CLI_VERSION=5:29.9.3-1~ubuntu.24.04~noble
ARG MICROSOFT_ASC_SHA256=2fa9c05d591a1582a9aba276272478c262e95ad00acf60eaee1644d93941e3c6
ARG DOCKER_ASC_SHA256=1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSLo /etc/apt/keyrings/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc \
    && echo "${MICROSOFT_ASC_SHA256}  /etc/apt/keyrings/microsoft.asc" | sha256sum -c - \
    && curl -fsSLo /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg \
    && echo "${DOCKER_ASC_SHA256}  /etc/apt/keyrings/docker.asc" | sha256sum -c - \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/azure-cli/ noble main" > /etc/apt/sources.list.d/azure-cli.list \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "azure-cli=${AZURE_CLI_VERSION}" "docker-ce-cli=${DOCKER_CLI_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

# kubectl, for the AKS clusters.
ARG KUBECTL_VERSION=1.37.2
ARG KUBECTL_SHA256=c04487523e7aa7d1493f7808174c899db93d7a9cf57531420cd76b9bd415f8f4
RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum -c - \
    && chmod 0755 /usr/local/bin/kubectl

# Helm, for the service's charts.
ARG HELM_VERSION=4.3.1
ARG HELM_SHA256=0403a88ae20913d11b10a2467b50087721fea7581736da6b9d3992f5357fe54b
RUN curl -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    && echo "${HELM_SHA256}  /tmp/helm.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/helm.tar.gz -C /usr/local/bin --strip-components=1 --no-same-owner linux-amd64/helm \
    && rm /tmp/helm.tar.gz

# Terraform, for infra/. It comes as a zip, so unzip is installed for this step only.
ARG TERRAFORM_VERSION=1.17.2
ARG TERRAFORM_SHA256=e6f16b2f0b137ee5729caa8c4e79a3bae4ee261acd198a1fcfa8584a6296605b
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && echo "${TERRAFORM_SHA256}  /tmp/terraform.zip" | sha256sum -c - \
    && unzip -q /tmp/terraform.zip terraform -d /usr/local/bin \
    && rm /tmp/terraform.zip \
    && apt-get purge -y --auto-remove unzip \
    && rm -rf /var/lib/apt/lists/*

# k6, for the load tests in perf/.
ARG K6_VERSION=2.3.0
ARG K6_SHA256=39c3117b6af817592dcd0ce4242105c0a7af10948c2a425306f0be8f7a8a8ab1
RUN curl -fsSLo /tmp/k6.tar.gz "https://github.com/grafana/k6/releases/download/v${K6_VERSION}/k6-v${K6_VERSION}-linux-amd64.tar.gz" \
    && echo "${K6_SHA256}  /tmp/k6.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/k6.tar.gz -C /usr/local/bin --strip-components=1 --no-same-owner "k6-v${K6_VERSION}-linux-amd64/k6" \
    && rm /tmp/k6.tar.gz

# Trivy, to scan images and dependencies for known vulnerabilities.
ARG TRIVY_VERSION=0.76.1
ARG TRIVY_SHA256=c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0
RUN curl -fsSLo /tmp/trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    && echo "${TRIVY_SHA256}  /tmp/trivy.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin --no-same-owner trivy \
    && rm /tmp/trivy.tar.gz

# gitleaks, which the pre-commit hook below runs.
ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
RUN curl -fsSLo /tmp/gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    && echo "${GITLEAKS_SHA256}  /tmp/gitleaks.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin --no-same-owner gitleaks \
    && rm /tmp/gitleaks.tar.gz

# Node.js, for tools/ai-developer and for npx to start the Azure DevOps MCP server in .mcp.json.
ARG NODE_VERSION=24.22.3
ARG NODE_SHA256=061ec3e3062115705b56b51fa9cc330ab50d34b6969387d4e4b1a50c6809acc2
RUN curl -fsSLo /tmp/node.tar.gz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" \
    && echo "${NODE_SHA256}  /tmp/node.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/node.tar.gz -C /usr/local --strip-components=1 --no-same-owner "node-v${NODE_VERSION}-linux-x64/bin" "node-v${NODE_VERSION}-linux-x64/lib" \
    && rm /tmp/node.tar.gz

# SqlPackage, to deploy the dacpac, in a folder that's on PATH for every user.
ARG SQLPACKAGE_VERSION=170.5.96
RUN dotnet tool install microsoft.sqlpackage --version "${SQLPACKAGE_VERSION}" --tool-path /opt/dotnet-tools
ENV PATH="${PATH}:/opt/dotnet-tools"

# The Aspire CLI for ubuntu, the dev container's user. VS Code's Aspire extension runs it, and the
# AppHost's build uses its dashboard and orchestrator instead of downloading its own copy. The CLI
# unpacks those beside itself, so each user needs a copy of their own: devcontainer.json puts this
# one on PATH, and a container job's AppHost build gets its own through dnx, as on Microsoft's
# hosted agents. Keep ASPIRE_CLI_VERSION at the Aspire.AppHost.Sdk version in global.json.
ARG ASPIRE_CLI_VERSION=13.6.5
USER ubuntu
RUN dotnet tool install --global Aspire.Cli --version "${ASPIRE_CLI_VERSION}" \
    && ~/.dotnet/tools/aspire setup
USER root

# The pre-commit hook that refuses a commit holding a secret (GATE-6), set for every repo in the
# container through git's system config, so a clone needs no setup.
COPY --chmod=0755 git-hooks/pre-commit /usr/local/share/git-hooks/pre-commit
RUN git config --system core.hooksPath /usr/local/share/git-hooks

# The folders devcontainer.json mounts volumes and files on, made here so ubuntu owns them.
RUN install -d -o ubuntu -g ubuntu /home/ubuntu/.claude /home/ubuntu/.nuget /home/ubuntu/.nuget/packages \
    && install -d -m 0700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
