namespace GroundWerk.Host;

internal static partial class HostLog
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Starting as role {Role}")]
    public static partial void StartingAsRole(ILogger logger, HostRole role);
}
