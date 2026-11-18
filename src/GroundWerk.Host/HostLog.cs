namespace GroundWerk.Host;

internal static partial class HostLog
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Starting {Version} as role {Role}")]
    public static partial void Starting(ILogger logger, string version, HostRole role);
}
