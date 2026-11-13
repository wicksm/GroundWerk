var builder = DistributedApplication.CreateBuilder(args);

builder.AddProject<Projects.GroundWerk_Host>("api")
    .WithEnvironment("Role", "api")
    .WithHttpHealthCheck("/health");

builder.AddProject<Projects.GroundWerk_Host>("jobs", launchProfileName: null)
    // A fixed port, like api's 5291, so every run uses the same ports (AGENTS.md).
    .WithHttpEndpoint(port: 5292)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", builder.Environment.EnvironmentName)
    .WithEnvironment("Role", "jobs")
    .WithHttpHealthCheck("/health");

builder.Build().Run();
