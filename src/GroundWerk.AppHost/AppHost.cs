var builder = DistributedApplication.CreateBuilder(args);

builder.AddProject<Projects.GroundWerk_Host>("api")
    .WithEnvironment("Role", "api")
    .WithHttpHealthCheck("/health");

builder.AddProject<Projects.GroundWerk_Host>("jobs", launchProfileName: null)
    .WithHttpEndpoint()
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", builder.Environment.EnvironmentName)
    .WithEnvironment("Role", "jobs")
    .WithHttpHealthCheck("/health");

builder.Build().Run();
