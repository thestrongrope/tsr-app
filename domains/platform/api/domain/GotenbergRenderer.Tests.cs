using System.Net;
using Microsoft.Extensions.Options;
using NUnit.Framework;

namespace Tsr.Platform.Api.Domain;

[TestFixture]
internal sealed class GotenbergRendererTests
{
    private sealed class Handler(Func<HttpRequestMessage, Task<HttpResponseMessage>> answer) : HttpMessageHandler
    {
        public string? Path { get; private set; }

        public string? Body { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Path = request.RequestUri!.AbsolutePath;
            Body = await request.Content!.ReadAsStringAsync(cancellationToken);
            return await answer(request);
        }
    }

    private static GotenbergRenderer Renderer(Handler handler) =>
        new(new HttpClient(handler), Options.Create(new GotenbergSettings { Url = "http://gotenberg:3000" }));

    private static Handler Answering(HttpStatusCode status, string body) =>
        new(_ => Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(body) }));

    [Test]
    public async Task The_page_is_posted_as_the_file_index_html_of_a_multipart_form_to_the_chromium_route_and_the_pdf_is_returned()
    {
        var handler = Answering(HttpStatusCode.OK, "%PDF-1.7 body");

        var result = await Renderer(handler).RenderAsync("<html>page</html>", CancellationToken.None);

        Assert.That(result.IsSuccess, Is.True, result.Error);
        Assert.That(handler.Path, Is.EqualTo("/forms/chromium/convert/html"));
        Assert.That(handler.Body, Does.Contain("name=files").And.Contain("filename=index.html").And.Contain("<html>page</html>"));
    }

    [TestCase(HttpStatusCode.BadRequest)]
    [TestCase(HttpStatusCode.ServiceUnavailable)]
    public async Task An_error_answer_is_a_failure(HttpStatusCode status) =>
        Assert.That((await Renderer(Answering(status, "text")).RenderAsync("x", CancellationToken.None)).IsSuccess, Is.False);

    [Test]
    public async Task An_answer_that_is_not_a_pdf_is_a_failure() =>
        Assert.That((await Renderer(Answering(HttpStatusCode.OK, "<html>no</html>")).RenderAsync("x", CancellationToken.None)).IsSuccess, Is.False);

    [Test]
    public async Task A_connection_error_and_a_timeout_are_failures()
    {
        var down = new Handler(_ => throw new HttpRequestException("refused"));
        var slow = new Handler(_ => throw new TaskCanceledException("timeout"));

        Assert.That((await Renderer(down).RenderAsync("x", CancellationToken.None)).IsSuccess, Is.False);
        Assert.That((await Renderer(slow).RenderAsync("x", CancellationToken.None)).IsSuccess, Is.False);
    }
}
