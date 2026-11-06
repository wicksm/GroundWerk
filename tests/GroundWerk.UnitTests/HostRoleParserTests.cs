using GroundWerk.Host;

namespace GroundWerk.UnitTests;

public class HostRoleParserTests
{
    [Fact]
    public void ParsesLowercaseApiAsApi()
    {
        Assert.Equal(HostRole.Api, HostRoleParser.Parse("api"));
    }

    [Fact]
    public void ParsesUppercaseJobsAsJobs()
    {
        Assert.Equal(HostRole.Jobs, HostRoleParser.Parse("JOBS"));
    }

    [Fact]
    public void RejectsEmptyStringWithMessageShowingIt()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => HostRoleParser.Parse(string.Empty));
        Assert.Equal("Role must be api or jobs, but was ''.", ex.Message);
    }

    [Fact]
    public void RejectsNullWithMessageSayingItIsMissing()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => HostRoleParser.Parse(null));
        Assert.Equal("Role must be api or jobs, but was (missing).", ex.Message);
    }

    [Fact]
    public void RejectsUnknownValueWithMessageShowingIt()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => HostRoleParser.Parse("batch"));
        Assert.Equal("Role must be api or jobs, but was 'batch'.", ex.Message);
    }
}
