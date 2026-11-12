namespace GroundWerk.Host;

public static class HostRoleParser
{
    public static HostRole Parse(string? value)
    {
        var trimmed = value?.Trim();

        if (string.Equals(trimmed, "api", StringComparison.OrdinalIgnoreCase))
        {
            return HostRole.Api;
        }

        if (string.Equals(trimmed, "jobs", StringComparison.OrdinalIgnoreCase))
        {
            return HostRole.Jobs;
        }

        var shown = value is null ? "(missing)" : $"'{value}'";
        throw new InvalidOperationException($"Role must be api or jobs, but was {shown}.");
    }
}
