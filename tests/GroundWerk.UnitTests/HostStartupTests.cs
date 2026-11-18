using System.Net;
using System.Reflection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Logging;

namespace GroundWerk.UnitTests;

public class HostStartupTests
{
    [Theory]
    [InlineData("api")]
    [InlineData("jobs")]
    public async Task StartsHealthyInEachRole(string role)
    {
        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder.UseSetting("Role", role));
        using var client = factory.CreateClient();

        using var response = await client.GetAsync(new Uri("/health", UriKind.Relative), TestContext.Current.CancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("api", "Api")]
    [InlineData("jobs", "Jobs")]
    public async Task LogsVersionAndRoleOnStartInEachRole(string role, string expectedRole)
    {
        var expectedVersion = typeof(Program).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
        Assert.False(string.IsNullOrEmpty(expectedVersion));

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder
                .UseSetting("Role", role)
                .ConfigureLogging(logging => logging.AddFakeLogging()));
        var collector = factory.Services.GetFakeLogCollector();

        var startup = Assert.Single(collector.GetSnapshot(), record => record.Id.Name == "Starting");

        Assert.Equal(LogLevel.Information, startup.Level);
        Assert.Contains(expectedVersion, startup.Message, StringComparison.Ordinal);
        Assert.Contains(expectedRole, startup.Message, StringComparison.Ordinal);
        Assert.Equal(expectedVersion, startup.GetStructuredStateValue("Version"));
        Assert.Equal(expectedRole, startup.GetStructuredStateValue("Role"));
    }
}
