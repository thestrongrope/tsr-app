using System.Net;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api;

[TestFixture]
internal sealed class ReportExportTests
{
    private sealed class FakeRenderer(Result<byte[]> answer) : IPdfRenderer
    {
        public string? Html { get; private set; }

        public Task<Result<byte[]>> RenderAsync(string html, CancellationToken ct)
        {
            Html = html;
            return Task.FromResult(answer);
        }
    }

    private static readonly ReportSection[] Sections = [new("Gents", ["A"], [new object?[] { "x" }])];

    private static async Task<(int Status, string? Type, string? Disposition, byte[] Body)> RunAsync(IResult result)
    {
        var context = new DefaultHttpContext { RequestServices = new ServiceCollection().AddLogging().BuildServiceProvider() };
        using var body = new MemoryStream();
        context.Response.Body = body;
        await result.ExecuteAsync(context);
        return (context.Response.StatusCode, context.Response.ContentType, context.Response.Headers.ContentDisposition.ToString(), body.ToArray());
    }

    [TestCase("xlsx", true, ReportFormat.Xlsx)]
    [TestCase("pdf", true, ReportFormat.Pdf)]
    [TestCase("XLSX", false, ReportFormat.Xlsx)]
    [TestCase("csv", false, ReportFormat.Xlsx)]
    [TestCase("", false, ReportFormat.Xlsx)]
    [TestCase(null, false, ReportFormat.Xlsx)]
    [TestCase("xlsx,pdf", false, ReportFormat.Xlsx)]
    [TestCase("pdf\n", false, ReportFormat.Xlsx)]
    public void Only_the_exact_words_xlsx_and_pdf_are_formats(string? text, bool expected, ReportFormat format)
    {
        Assert.That(ReportExport.TryParseFormat(text, out var parsed), Is.EqualTo(expected));
        if (expected)
        {
            Assert.That(parsed, Is.EqualTo(format));
        }
    }

    private static DefaultHttpContext Asking(string query) => new() { Request = { QueryString = new QueryString(query) } };

    [Test]
    public void The_format_is_read_from_the_query_and_the_last_one_given_counts()
    {
        Assert.That(ReportExport.FormatRefusal(Asking("?format=pdf")), Is.Null);
        Assert.That(ReportExport.FormatRefusal(Asking("?format=csv&format=xlsx")), Is.Null);
        Assert.That(ReportExport.TryGetFormat(Asking("?format=pdf"), out var format) && format == ReportFormat.Pdf, Is.True);
        Assert.That(ReportExport.FormatRefusal(Asking("?format=xlsx&format=csv")), Is.Not.Null);
        Assert.That(ReportExport.FormatRefusal(Asking(string.Empty)), Is.Not.Null);
    }

    [Test]
    public async Task A_refused_format_is_422_with_the_PHP_text()
    {
        var (status, _, _, body) = await RunAsync(ReportExport.FormatRefusal(Asking("?format=csv"))!);

        Assert.That(status, Is.EqualTo(422));
        Assert.That(Encoding.UTF8.GetString(body), Is.EqualTo("{\"detail\":\"format must be xlsx or pdf\"}"));
    }

    [Test]
    public async Task An_xlsx_download_is_the_workbook_with_the_spreadsheet_type_and_an_attachment_name()
    {
        var export = new ReportExport(new FakeRenderer(Result.Fail<byte[]>("unused")), NullLogger<ReportExport>.Instance);

        var (status, type, disposition, body) = await RunAsync(await export.DownloadAsync(ReportFormat.Xlsx, "T", Sections, "Active-teachers-Gents", CancellationToken.None));

        Assert.That(status, Is.EqualTo(200));
        Assert.That(type, Is.EqualTo("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
        Assert.That(disposition, Is.EqualTo("attachment; filename=\"Active-teachers-Gents.xlsx\""));
        Assert.That(body.Take(2).ToArray(), Is.EqualTo((byte[])[(byte)'P', (byte)'K']));
    }

    [TestCase("Active-teachers-Gents", "Active-teachers-Gents")]
    [TestCase("Class_Sessions_RB-G-593", "Class_Sessions_RB-G-593")]
    [TestCase("a\"b\r\nc;d", "a_b__c_d")]
    [TestCase("\u0645\u062d", "__")]
    public void A_file_name_keeps_only_safe_characters(string name, string expected) =>
        Assert.That(ReportExport.SafeName(name), Is.EqualTo(expected));

    [Test]
    public async Task A_pdf_download_sends_the_escaped_page_to_the_renderer_and_returns_its_bytes()
    {
        var renderer = new FakeRenderer(Result.Ok(Encoding.ASCII.GetBytes("%PDF-fake")));
        var export = new ReportExport(renderer, NullLogger<ReportExport>.Instance);

        var (status, type, disposition, body) = await RunAsync(await export.DownloadAsync(ReportFormat.Pdf, "<b>T</b>", Sections, "Weekly-Gents", CancellationToken.None));

        Assert.That(status, Is.EqualTo(200));
        Assert.That(type, Is.EqualTo("application/pdf"));
        Assert.That(disposition, Is.EqualTo("attachment; filename=\"Weekly-Gents.pdf\""));
        Assert.That(Encoding.ASCII.GetString(body), Is.EqualTo("%PDF-fake"));
        Assert.That(renderer.Html, Does.Contain("<h1>&lt;b&gt;T&lt;/b&gt;</h1>"));
    }

    [Test]
    public async Task A_renderer_that_fails_is_a_503_with_a_detail_and_never_the_renderer_text()
    {
        var export = new ReportExport(new FakeRenderer(Result.Fail<byte[]>("secret internal text")), NullLogger<ReportExport>.Instance);

        var (status, _, disposition, body) = await RunAsync(await export.DownloadAsync(ReportFormat.Pdf, "T", Sections, "X", CancellationToken.None));

        Assert.That(status, Is.EqualTo((int)HttpStatusCode.ServiceUnavailable));
        Assert.That(disposition, Is.Empty);
        var text = Encoding.UTF8.GetString(body);
        Assert.That(text, Does.Contain("\"detail\""));
        Assert.That(text, Does.Not.Contain("secret"));
    }
}
