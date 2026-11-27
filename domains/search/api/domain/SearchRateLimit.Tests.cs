using System.Net;
using Microsoft.AspNetCore.Http;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>SRCH-R14: 60 requests a minute per client and route; the 61st is a 429 in the website's rate limit shape. The clock is a fake one.</summary>
[TestFixture]
internal sealed class SearchRateLimitTests
{
    private sealed class ManualClock(DateTimeOffset start) : TimeProvider
    {
        private DateTimeOffset now = start;

        public override DateTimeOffset GetUtcNow() => now;

        public void Advance(TimeSpan by) => now += by;
    }

    private static readonly DateTimeOffset Start = new(2030, 1, 1, 12, 0, 0, TimeSpan.Zero);

    private readonly ManualClock clock = new(Start);

    [Test]
    public async Task The_61st_request_in_a_minute_is_a_429_with_the_websites_body_and_headers()
    {
        var limit = new MemberRateLimit(clock);
        for (var i = 1; i <= 60; i++)
        {
            Assert.That(SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.ArticleBucket), Is.Null, "request " + i);
        }

        clock.Advance(TimeSpan.FromSeconds(20));
        var refusal = SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.ArticleBucket);

        Assert.That(refusal, Is.Not.Null);
        var context = Caller("203.0.113.9");
        context.Response.Body = new MemoryStream();
        await refusal!.ExecuteAsync(context);
        context.Response.Body.Position = 0;
        var body = await new StreamReader(context.Response.Body).ReadToEndAsync();
        Assert.That(context.Response.StatusCode, Is.EqualTo(429));
        Assert.That(body, Is.EqualTo("""{"success":false,"error":"Too many requests"}"""));
        Assert.That(context.Response.ContentType, Is.EqualTo("application/json"));
        Assert.That(context.Response.Headers["Retry-After"].ToString(), Is.EqualTo("40"));
        Assert.That(context.Response.Headers["X-RateLimit-Limit"].ToString(), Is.EqualTo("60"));
        Assert.That(context.Response.Headers["X-RateLimit-Remaining"].ToString(), Is.EqualTo("0"));
        Assert.That(context.Response.Headers.AccessControlAllowOrigin.ToString(), Is.EqualTo("*"));
        Assert.That(context.Response.Headers.ContainsKey("Cache-Control"), Is.False);
    }

    [Test]
    public void The_two_routes_and_two_clients_have_their_own_counts()
    {
        var limit = new MemberRateLimit(clock);
        for (var i = 1; i <= 60; i++)
        {
            Assert.That(SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.ArticleBucket), Is.Null);
        }

        Assert.That(SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.ArticleBucket), Is.Not.Null);
        Assert.That(SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.LectureBucket), Is.Null, "the lecture route");
        Assert.That(SearchRateLimit.Refuse(limit, Caller("203.0.113.10"), SearchRateLimit.ArticleBucket), Is.Null, "another client");
    }

    [Test]
    public void The_window_slides_so_a_minute_later_the_client_is_served_again()
    {
        var limit = new MemberRateLimit(clock);
        for (var i = 1; i <= 61; i++)
        {
            _ = SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.ArticleBucket);
        }

        clock.Advance(TimeSpan.FromSeconds(61));

        Assert.That(SearchRateLimit.Refuse(limit, Caller("203.0.113.9"), SearchRateLimit.ArticleBucket), Is.Null);
    }

    private static DefaultHttpContext Caller(string address)
    {
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse(address);
        return context;
    }
}
