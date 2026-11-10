using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace Tsr.Platform.Contract.Tests;

/// <summary>
/// POST /feedback, as specified in ../api.yaml. Every implementation must pass these, the PHP
/// route included; that is what lets the gateway move the path without the app noticing.
/// </summary>
public sealed class SubmitFeedbackContractTests
{
    [Fact]
    public async Task Without_sign_in_it_is_401_with_a_detail()
    {
        using var client = Target.Anonymous();

        var response = await client.PostAsJsonAsync("/feedback", new { clientId = NewId(), text = "salaam" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        await AssertDetailAsync(response);
    }

    [Fact]
    public async Task A_member_sends_feedback_and_gets_201_with_an_id()
    {
        using var client = Target.Member();

        var response = await client.PostAsJsonAsync("/feedback", new { clientId = NewId(), text = "JazakAllah for the app" });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.True(await IdOfAsync(response) > 0);
    }

    [Fact]
    public async Task A_replay_with_the_same_clientId_returns_the_same_id()
    {
        using var client = Target.Member();
        var body = new { clientId = NewId(), text = "sent twice because the reply was lost" };

        var first = await client.PostAsJsonAsync("/feedback", body);
        var second = await client.PostAsJsonAsync("/feedback", body);

        Assert.Equal(HttpStatusCode.Created, second.StatusCode);
        Assert.Equal(await IdOfAsync(first), await IdOfAsync(second));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Empty_text_is_422(string text)
    {
        using var client = Target.Member();

        var response = await client.PostAsJsonAsync("/feedback", new { clientId = NewId(), text });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
        await AssertDetailAsync(response);
    }

    [Fact]
    public async Task Text_over_2000_characters_is_422()
    {
        using var client = Target.Member();

        var response = await client.PostAsJsonAsync("/feedback", new { clientId = NewId(), text = new string('a', 2001) });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
    }

    [Fact]
    public async Task A_missing_clientId_is_422()
    {
        using var client = Target.Member();

        var response = await client.PostAsJsonAsync("/feedback", new { text = "no id" });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
        await AssertDetailAsync(response);
    }

    private static string NewId() => Guid.NewGuid().ToString();

    private static async Task<int> IdOfAsync(HttpResponseMessage response)
    {
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return json.RootElement.GetProperty("id").GetInt32();
    }

    private static async Task AssertDetailAsync(HttpResponseMessage response)
    {
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.False(string.IsNullOrWhiteSpace(json.RootElement.GetProperty("detail").GetString()));
    }
}
