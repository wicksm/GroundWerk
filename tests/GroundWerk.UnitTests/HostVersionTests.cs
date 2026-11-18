using System.Reflection;
using System.Reflection.Emit;
using GroundWerk.Host;

namespace GroundWerk.UnitTests;

public class HostVersionTests
{
    [Fact]
    public void ReturnsUnknownForAnAssemblyWithoutAnInformationalVersion()
    {
        var assembly = AssemblyBuilder.DefineDynamicAssembly(
            new AssemblyName("WithoutInformationalVersion"),
            AssemblyBuilderAccess.Run);

        Assert.Equal("unknown", HostVersion.From(assembly));
    }

    [Fact]
    public void ReturnsTheInformationalVersionOfAnAssemblyUnchanged()
    {
        var constructor = typeof(AssemblyInformationalVersionAttribute).GetConstructor([typeof(string)])!;
        var attribute = new CustomAttributeBuilder(constructor, ["1.2.3-alpha.0.4+abc123"]);
        var assembly = AssemblyBuilder.DefineDynamicAssembly(
            new AssemblyName("WithInformationalVersion"),
            AssemblyBuilderAccess.Run,
            [attribute]);

        Assert.Equal("1.2.3-alpha.0.4+abc123", HostVersion.From(assembly));
    }
}
