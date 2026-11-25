using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The report workbook is written by our own code (<c>ReportXlsx</c>). ClosedXML and its six dependencies raise a trim warning (IL2090) in a
/// native build that cannot be silenced for one library, so none of them may come back into the API through any project it references.
/// </summary>
public sealed class NoSpreadsheetLibraryTests
{
    private static readonly string[] SpreadsheetPackages =
        ["ClosedXML", "ClosedXML.Parser", "DocumentFormat.OpenXml", "DocumentFormat.OpenXml.Framework", "ExcelNumberFormat", "RBush.Signed", "SixLabors.Fonts"];

    [Test]
    public void The_api_carries_no_spreadsheet_library()
    {
        var assets = Path.Combine(RouteCatalog.RepoRoot(), "hosts", "api", "obj", "project.assets.json");
        using var document = JsonDocument.Parse(File.ReadAllText(assets));

        var restored = document.RootElement.GetProperty("libraries").EnumerateObject()
            .Select(library => library.Name[..library.Name.IndexOf('/', StringComparison.Ordinal)])
            .ToList();

        Assert.That(restored.Intersect(SpreadsheetPackages, StringComparer.OrdinalIgnoreCase), Is.Empty);
    }
}
