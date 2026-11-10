using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// POST /feedback against a real database, through the API as the limited role: one feedback row and
/// one outbox row per new message, none on a replay, and nothing committed when the outbox write fails.
/// </summary>
public sealed class FeedbackTests
{
    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() =>
        factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task CleanAsync() => TestDatabase.ExecuteAsync(
        """
        truncate platform.feedback, platform.outbox;
        insert into identity.users (token, gender, email, firebase_uid)
        select 900001, 1, 'member.gents@example.invalid', 'uid-feedback'
        where not exists (select 1 from identity.users where token = 900001);
        """);

    [Test]
    public async Task A_new_message_writes_one_feedback_row_and_one_outbox_row()
    {
        var response = await PostAsync("client-a", "salaam");

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.Created));
        Assert.That(await CountAsync("platform.feedback"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_replay_of_the_same_client_id_writes_neither()
    {
        await PostAsync("client-b", "salaam");

        var replay = await PostAsync("client-b", "salaam");

        Assert.That(replay.StatusCode, Is.EqualTo(HttpStatusCode.Created));
        Assert.That(await CountAsync("platform.feedback"), Is.EqualTo(1));
        Assert.That(await CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task When_the_outbox_insert_fails_the_feedback_row_is_not_committed()
    {
        await TestDatabase.ExecuteAsync(
            """
            create function platform.fail_outbox() returns trigger language plpgsql as
            $$ begin raise exception 'outbox unavailable (test)'; end $$;
            create trigger fail_outbox before insert on platform.outbox
            for each row execute function platform.fail_outbox();
            """);
        try
        {
            var response = await PostAsync("client-c", "salaam");

            Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.InternalServerError));
            Assert.That(await CountAsync("platform.feedback"), Is.EqualTo(0));
            Assert.That(await CountAsync("platform.outbox"), Is.EqualTo(0));
        }
        finally
        {
            await TestDatabase.ExecuteAsync(
                "drop trigger fail_outbox on platform.outbox; drop function platform.fail_outbox();");
        }
    }

    private async Task<HttpResponseMessage> PostAsync(string clientId, string text)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, "/feedback")
        {
            Content = JsonContent.Create(new { clientId, text }),
        };
        foreach (var (name, value) in TestApi.SignedInAs("uid-feedback", "member.gents@example.invalid"))
        {
            request.Headers.Add(name, value);
        }

        return await client.SendAsync(request);
    }

    private static Task<long> CountAsync(string table) =>
        TestDatabase.ScalarAsync<long>("select count(*) from " + table, TestDatabase.OwnerConnection);
}
