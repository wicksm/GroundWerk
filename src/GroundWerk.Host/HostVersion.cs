using System.Reflection;

namespace GroundWerk.Host;

public static class HostVersion
{
    public static string Current { get; } = From(typeof(HostVersion).Assembly);

    public static string From(Assembly assembly) =>
        assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? "unknown";
}
