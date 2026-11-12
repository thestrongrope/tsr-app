using System.Globalization;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>One account deletion request with the member's details joined in (PHP <c>account_deletion_requests</c> row plus <c>users</c> and the handler's name).</summary>
internal sealed record DeletionRow(
    int Id,
    string Status,
    string Source,
    int? Token,
    string? MemberName,
    string? MemberEmail,
    string? MemberZip,
    string? MemberMobile,
    string? ContactName,
    string? ContactEmail,
    DateTimeOffset RequestedAt,
    string? Reason,
    string? OperatorNote,
    DateTimeOffset? ConfirmationSentAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? CancelledAt,
    int? HandledBy,
    string? HandledByName);

/// <summary>
/// The wire shapes and wording of the deletion routes, with no database: PHP's <c>api_deletion_request_view</c> (the member's view), <c>api_admin_deletion_view</c> (the
/// administrator's) and <c>AccountDeletionModel::confirmationEmail</c>. Every key is present in every response, absence is null (the typed Dart models crash otherwise).
/// </summary>
internal static class DeletionViews
{
    public const int GraceDays = 60;
    public const string PendingMessage = "Your account will be deleted within 60 days.";
    public const string PrizeMessage = "We are still delivering a prize to you. Your account will be deleted once that is complete.";

    public const string Pending = "pending";
    public const string AwaitingPrize = "awaiting_prize_delivery";
    public const string Completed = "completed";
    public const string Cancelled = "cancelled";

    /// <summary>The statuses an administrator may filter by, in the order of the <c>counts</c> object.</summary>
    public static readonly string[] Statuses = [Pending, AwaitingPrize, Completed, Cancelled];

    /// <summary>The statuses that count as live: the member is waiting on us.</summary>
    public static readonly string[] Live = [Pending, AwaitingPrize];

    public static bool IsLive(string status) => Live.Contains(status, StringComparer.Ordinal);

    /// <summary>PHP api_cast 'datetime': <c>Y-m-d\TH:i:s</c>, no zone (stored times are UTC).</summary>
    public static string? Stamp(DateTimeOffset? value) => value?.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture);

    /// <summary>The sentence shown under the status (PHP <c>api_deletion_message</c>).</summary>
    public static string? Message(string status, string? operatorNote)
    {
        if (status == AwaitingPrize)
        {
            return string.IsNullOrEmpty(operatorNote) || PhpText.Trim(operatorNote).Length == 0 ? PrizeMessage : operatorNote;
        }

        return status == Pending ? PendingMessage : null;
    }

    /// <summary>What the member sees: the live request, or the same shape with status "none" when there is none.</summary>
    public static Dictionary<string, object?> MemberView(DeletionRow? row)
    {
        var status = row?.Status ?? "none";
        return new Dictionary<string, object?>
        {
            ["id"] = row?.Id,
            ["status"] = status,
            ["requested_at"] = Stamp(row?.RequestedAt),
            ["expected_completion_days"] = GraceDays,
            ["message"] = Message(status, row?.OperatorNote),
        };
    }

    /// <summary>What an administrator sees (PHP <c>api_admin_deletion_view</c>). <paramref name="demoTokens"/> are the reviewer demo members, who can never be completed.</summary>
    public static Dictionary<string, object?> AdminView(DeletionRow row, IReadOnlyCollection<int> demoTokens)
    {
        var live = IsLive(row.Status);
        var confirmed = row.ConfirmationSentAt is not null;
        var isDemo = row.Token is int token && demoTokens.Contains(token);
        var held = row.Status == AwaitingPrize;
        var name = FirstTruthy(row.MemberName, row.ContactName);
        var email = FirstTruthy(row.MemberEmail, row.ContactEmail);

        var view = new Dictionary<string, object?>
        {
            ["id"] = row.Id,
            ["status"] = row.Status,
            ["source"] = row.Source,
            ["token"] = row.Token,
            ["member_name"] = Text(name),
            ["contact_email"] = Text(email),
            ["requested_at"] = Stamp(row.RequestedAt),
            ["reason"] = Text(row.Reason),
            ["operator_note"] = Text(row.OperatorNote),
            ["confirmation_sent_at"] = Stamp(row.ConfirmationSentAt),
            ["completed_at"] = Stamp(row.CompletedAt),
            ["cancelled_at"] = Stamp(row.CancelledAt),
            ["handled_by"] = row.HandledBy,
            ["handled_by_name"] = Text(row.HandledByName),
            ["member_zip"] = held ? Text(row.MemberZip) : null,
            ["member_mobile"] = held ? Text(row.MemberMobile) : null,
            ["is_demo"] = isDemo,
            ["can_complete"] = live && confirmed && !isDemo && (row.Token is null || row.Token > 0),
            ["confirmation"] = null,
        };

        if (live && !confirmed)
        {
            var mail = ConfirmationEmail(name ?? string.Empty);
            view["confirmation"] = new Dictionary<string, object?> { ["to"] = Text(email), ["subject"] = mail.Subject, ["body"] = mail.Body };
        }

        return view;
    }

    /// <summary>The confirmation the operator sends, ready to copy (PHP <c>confirmationEmail</c>; the wording matches the privacy policy).</summary>
    public static (string Subject, string Body) ConfirmationEmail(string name)
    {
        var trimmed = PhpText.Trim(name);
        var greeting = trimmed.Length > 0 ? trimmed : "there";
        var body = "Dear " + greeting + ",\n\n"
            + "We have finished deleting your The Strong Rope account, as you asked.\n\n"
            + "The personal details we held about you -- your name, email address, "
            + "profile picture, mobile number, gender, age range and location -- have been "
            + "removed.\n\n"
            + "Your class attendance and quiz records have been kept without anything "
            + "identifying you, so class statistics stay accurate.\n\n"
            + "You will not receive any further messages from us. If you would like to "
            + "join us again in future you are very welcome to sign up afresh.\n\n"
            + "With salaams,\n"
            + "The Strong Rope\n"
            + "thestrongrope@gmail.com";
        return ("Your The Strong Rope account has been deleted", body);
    }

    // PHP's `$a ?: $b`: an empty (or "0") first value falls through to the second.
    private static string? FirstTruthy(string? first, string? second) =>
        string.IsNullOrEmpty(first) || first == "0" ? second : first;

    // api_cast 'text?': HTML entities decoded, null stays null.
    private static string? Text(string? value) => value is null ? null : PhpText.HtmlDecode(value);
}
