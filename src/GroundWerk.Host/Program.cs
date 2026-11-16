using InnerSource.Telemetry;
using GroundWerk.Host;

var builder = WebApplication.CreateBuilder(args);
var role = HostRoleParser.Parse(builder.Configuration["Role"]);

builder.AddTelemetry();
builder.Services.AddHealthChecks();

var app = builder.Build();

HostLog.StartingAsRole(app.Logger, role);

app.MapHealthChecks("/health");

app.Run();
