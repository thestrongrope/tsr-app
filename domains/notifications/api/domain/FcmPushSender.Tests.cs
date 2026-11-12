using System.Net;
using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

public sealed class FcmPushSenderTests
{
    [Test]
    public void An_unregistered_token_is_dead() =>
        Assert.That(
            FcmPushSender.Classify(HttpStatusCode.NotFound, """{"error":{"code":404,"status":"NOT_FOUND","message":"x","details":[{"errorCode":"UNREGISTERED"}]}}"""),
            Is.EqualTo(PushResult.TokenInvalid));

    [Test]
    public void A_bad_registration_token_is_dead() =>
        Assert.That(
            FcmPushSender.Classify(HttpStatusCode.BadRequest, """{"error":{"status":"INVALID_ARGUMENT","message":"The registration token is not a valid FCM registration token"}}"""),
            Is.EqualTo(PushResult.TokenInvalid));

    [Test]
    public void A_bad_payload_never_makes_a_token_dead() =>
        Assert.That(
            FcmPushSender.Classify(HttpStatusCode.BadRequest, """{"error":{"status":"INVALID_ARGUMENT","message":"Invalid value at message.data"}}"""),
            Is.EqualTo(PushResult.Failed));

    [TestCase(HttpStatusCode.Forbidden, """{"error":{"status":"PERMISSION_DENIED","details":[{"errorCode":"SENDER_ID_MISMATCH"}]}}""")]
    [TestCase(HttpStatusCode.NotFound, """{"error":{"status":"NOT_FOUND","message":"Requested entity was not found."}}""")]
    [TestCase(HttpStatusCode.TooManyRequests, """{"error":{"status":"RESOURCE_EXHAUSTED"}}""")]
    [TestCase(HttpStatusCode.BadGateway, "not json")]
    public void Any_other_refusal_is_a_failure_that_keeps_the_token(HttpStatusCode status, string body) =>
        Assert.That(FcmPushSender.Classify(status, body), Is.EqualTo(PushResult.Failed));
}
