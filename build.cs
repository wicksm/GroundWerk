#:package Bullseye
#:package SimpleExec
// A file-based app publishes with Native AOT by default. This script is only ever run, so
// turning that off saves restoring the AOT compiler's packages.
#:property PublishAot=false
// A pipeline compiles this script while SonarQube Cloud's analysis records what MSBuild builds,
// and the analysis is for the solution, not its build script.
#:property SonarQubeExclude=true

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

Target("test", "Run every test project, with TRX results and Cobertura coverage in artifacts/test-results", dependsOn: ["build"],
    () => RunAsync("dotnet", $"test --solution {Solution} --configuration {Configuration} --no-build --results-directory {TestResults} --report-xunit-trx --coverage --coverage-output-format cobertura"));

Target("pack", "Pack each project that ships as a NuGet package into artifacts/packages", dependsOn: ["build"], forEach: packageProjects,
    project => RunAsync("dotnet", $"pack {project} --configuration {Configuration} --no-build --output {Packages}"));

Target("publish", "Publish the Host and copy the dacpac into artifacts/publish", dependsOn: ["build"], async () =>
{
    // Never publish the solution: publishing the SQL project deploys its dacpac to a database.
    await RunAsync("dotnet", $"publish src/GroundWerk.Host --configuration {Configuration} --no-build --output {Publish}/GroundWerk.Host");
    Directory.CreateDirectory($"{Publish}/GroundWerk.Database");
    File.Copy($"src/GroundWerk.Database/bin/{Configuration}/GroundWerk.Database.dacpac", $"{Publish}/GroundWerk.Database/GroundWerk.Database.dacpac");
});

Target("check", "Check that every tracked text file ends with a newline, as .editorconfig asks", async () =>
{
    // .editorconfig asks for a newline at the end of every file, but only editors that read it add
    // one, and without it the next lines added at a file's end show its last line as changed too.
    var (tracked, _) = await ReadAsync("git", "ls-files -z");
    var missing = tracked.Split('\0', StringSplitOptions.RemoveEmptyEntries)
        .Where(file => File.Exists(file) && LacksFinalNewline(File.ReadAllBytes(file)))
        .ToList();
    if (missing.Count > 0)
    {
        throw new InvalidOperationException($"These files don't end with a newline, as .editorconfig asks: {string.Join(", ", missing)}");
    }

    // An empty file has no last line, and a NUL byte marks a binary file, such as an image.
    static bool LacksFinalNewline(byte[] bytes) =>
        bytes.Length > 0 && Array.IndexOf(bytes, (byte)0) < 0 && bytes[^1] != (byte)'\n';
});

Target("default", "Run check, test, pack and publish, then print what two runs of a commit should share", dependsOn: ["check", "test", "pack", "publish"], async () =>
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
