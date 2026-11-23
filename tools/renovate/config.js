// Renovate's config (CICD-17). Pipeline run-renovate runs Renovate on a schedule, signed in as
// groundwerk-renovate, and Renovate opens an upgrade PR in each repo the pipeline names when one
// of the shared packages, a release tag of the ci template or a pipeline task has
// a new version (docs/adr/0010). The pipeline gives it the token in RENOVATE_TOKEN, and the repos
// in RENOVATE_REPOSITORIES, from the private Settings repo (docs/adr/0012).
module.exports = {
  platform: 'azure',
  endpoint: 'https://dev.azure.com/mikewicks-lab/',

  // With what the pipeline sets, this file is the whole config, so the repos need no renovate.json
  // and get no onboarding PR
  onboarding: false,
  requireConfig: 'optional',

  // Each PR links Feature 21, "Upgrades open their own PRs", since main's policy needs a work item
  azureWorkItemId: 21,

  // No hourly limit. Renovate's default of 2 new PRs a clock hour in each repo would hold the rest
  // back until a run in the next hour, and it watches few enough packages to open them all at once.
  prHourlyLimit: 0,

  enabledManagers: ['nuget', 'azure-pipelines', 'custom.regex'],

  // Off unless enabled. It bumps the release tag that a pipeline's repository resource pins.
  'azure-pipelines': {
    enabled: true,
    managerFilePatterns: ['/^pipelines/.+\\.yml$/'],
  },

  // Every task in the pipelines and the templates, including the ones inside a condition, which
  // the Azure Pipelines manager skips
  customManagers: [
    {
      customType: 'regex',
      managerFilePatterns: ['/^(pipelines|stages)/.+\\.yml$/'],
      matchStrings: ['task:\\s*(?<depName>[\\w.-]+)@(?<currentValue>\\d+)'],
      datasourceTemplate: 'azure-pipelines-tasks',
    },
  ],

  packageRules: [
    // Only GroundWerk.InnerSource's packages, the shared ones that CICD-17 automates
    {
      matchManagers: ['nuget'],
      matchPackageNames: ['!GroundWerk.*'],
      enabled: false,
    },
    // The custom manager bumps every task, so the Azure Pipelines manager leaves them alone
    {
      matchManagers: ['azure-pipelines'],
      matchDatasources: ['azure-pipelines-tasks'],
      enabled: false,
    },
    // A pipeline pins a task by its major version, such as NuGetAuthenticate@1. Renovate finds the
    // tasks' versions in its public lists of Azure Pipelines' built-in and Marketplace tasks.
    {
      matchDatasources: ['azure-pipelines-tasks'],
      extractVersion: '^(?<version>\\d+)',
    },
  ],

  // The innersource feed, which takes the token as a password, as it does from NuGet
  hostRules: [
    {
      hostType: 'nuget',
      matchHost: 'https://pkgs.dev.azure.com/mikewicks-lab/',
      username: 'renovate',
      // Empty only when npm run check checks this file, outside the pipeline
      password: process.env.RENOVATE_TOKEN ?? '',
    },
  ],
};
