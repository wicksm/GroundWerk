#:package Bullseye
#:package SimpleExec
// A file-based app publishes with Native AOT by default. This script is only ever run, so
// turning that off saves restoring the AOT compiler's packages.
#:property PublishAot=false

using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Xml.Linq;
using static Bullseye.Targets;
using static SimpleExec.Command;

// GroundWerk's build, run the same way on a dev machine and in a pipeline (docs/adr/0005).
// dotnet run build.cs runs every target. Name targets to run fewer: dotnet run build.cs -- test.
// The paths below are from the repo root, wherever the script is started.
Directory.SetCurrentDirectory((string)AppContext.GetData("EntryPointFileDirectoryPath")!);

// The AppHost's build sets up the Aspire CLI with dnx, which it looks for on PATH. dnx sits beside
// dotnet in the .NET folder, but Microsoft-hosted agents link only dotnet onto PATH, so add that
// folder to the end of PATH, where it's used only when nothing before it has dnx.
var dotnetFolder = Path.GetFullPath(Path.Combine(RuntimeEnvironment.GetRuntimeDirectory(), "..", "..", ".."));
Environment.SetEnvironmentVariable("PATH", $"{Environment.GetEnvironmentVariable("PATH")}{Path.PathSeparator}{dotnetFolder}");

const string Solution = "GroundWerk.slnx";
const string Configuration = "Release";
const string TestResults = "artifacts/test-results";
const string Packages = "artifacts/packages";
const string Publish = "artifacts/publish";

// The projects that ship as NuGet packages. None does yet, since code that only
// GroundWerk's apps use stays a project reference (AGENTS.md).
string[] packageProjects = [];

Target("restore", "Restore the solution's NuGet packages",
    () => RunAsync("dotnet", $"restore {Solution}"));

Target("build", "Compile the solution in Release, the dacpac included", dependsOn: ["restore"], async () =>
{
    // MinVer counts the commits since the latest version tag, so a shallow clone, which is a
    // new pipeline's default checkout, would get the wrong version without any warning.
    var (shallow, _) = await ReadAsync("git", "rev-parse --is-shallow-repository");
    if (shallow.Trim() == "true")
    {
        throw new InvalidOperationException("This clone is shallow, so its version would be wrong. Check out with fetchDepth: 0, or run git fetch --unshallow.");
    }

    if (Directory.Exists("artifacts"))
    {
        Directory.Delete("artifacts", recursive: true);
    }

    await RunAsync("dotnet", $"build {Solution} --configuration {Configuration} --no-restore");
});

Target("test", "Run every test project, with TRX results in artifacts/test-results", dependsOn: ["build"],
    () => RunAsync("dotnet", $"test --solution {Solution} --configuration {Configuration} --no-build --results-directory {TestResults} --report-xunit-trx"));

Target("pack", "Pack each project that ships as a NuGet package into artifacts/packages", dependsOn: ["build"], forEach: packageProjects,
    project => RunAsync("dotnet", $"pack {project} --configuration {Configuration} --no-build --output {Packages}"));

Target("publish", "Publish the Host and copy the dacpac into artifacts/publish", dependsOn: ["build"], async () =>
{
    // Never publish the solution: publishing the SQL project deploys its dacpac to a database.
    await RunAsync("dotnet", $"publish src/GroundWerk.Host --configuration {Configuration} --no-build --output {Publish}/GroundWerk.Host");
    Directory.CreateDirectory($"{Publish}/GroundWerk.Database");
    File.Copy($"src/GroundWerk.Database/bin/{Configuration}/GroundWerk.Database.dacpac", $"{Publish}/GroundWerk.Database/GroundWerk.Database.dacpac");
});

Target("default", "Run test, pack and publish, then print what two runs of a commit should share", dependsOn: ["test", "pack", "publish"], async () =>
{
    var (sdk, _) = await ReadAsync("dotnet", "--version");
    var version = FileVersionInfo.GetVersionInfo($"{Publish}/GroundWerk.Host/GroundWerk.Host.dll").ProductVersion;
    var counters = Directory.GetFiles(TestResults, "*.trx", SearchOption.AllDirectories)
        .Select(file => XDocument.Load(file).Descendants().Single(element => element.Name.LocalName == "Counters"))
        .ToList();
    int Count(string outcome) => counters.Sum(element => (int)element.Attribute(outcome)!);
    var packed = Directory.Exists(Packages) ? Directory.GetFiles(Packages, "*.nupkg").Select(Path.GetFileName).Order().ToList() : [];

    Console.WriteLine($"SDK: {sdk.Trim()}");
    Console.WriteLine($"Version: {version}");
    Console.WriteLine($"Tests: {Count("total")} total, {Count("passed")} passed, {Count("failed")} failed");
    Console.WriteLine($"Packages: {(packed.Count == 0 ? "none" : string.Join(", ", packed))}");
});

await RunTargetsAndExitAsync(args, ex => ex is SimpleExec.ExitCodeException);
