using GroundWerk.Host;
using GroundWerk.Telemetry;

var builder = WebApplication.CreateBuilder(args);
var role = HostRoleParser.Parse(builder.Configuration["Role"]);

builder.AddTelemetry();
builder.Services.AddHealthChecks();

var app = builder.Build();

HostLog.Starting(app.Logger, HostVersion.Current, role);

app.MapHealthChecks("/health");

await app.RunAsync();
