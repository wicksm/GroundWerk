namespace GroundWerk.Host;

public static class HostRoleParser
{
    public static HostRole Parse(string? value)
    {
        if (string.Equals(value, "api", StringComparison.OrdinalIgnoreCase))
        {
            return HostRole.Api;
        }

        if (string.Equals(value, "jobs", StringComparison.OrdinalIgnoreCase))
        {
            return HostRole.Jobs;
        }

        var shown = value is null ? "(missing)" : $"'{value}'";
        throw new InvalidOperationException($"Role must be api or jobs, but was {shown}.");
    }
}
