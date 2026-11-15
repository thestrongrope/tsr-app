using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The page of a quiz's printable sheet, PHP's McqSheetModel::html (models/mcqsheet.php) word for word apart from the font: the quiz name, the topic (left out when empty or "0", PHP's falsy test) and the class, a line for the student's
/// name and date, then each question numbered with its options lettered a), b), ... in the order students see them and with NO answer marked. EVERY value is HTML-encoded (a name or a question a teacher typed cannot add markup) and the page
/// refers to no outside resource. PHP sets no text direction (an Arabic question is laid out left to right with the browser's own bidirectional handling).
/// </summary>
internal static partial class QuizSheet
{
    private const string Head =
        "<html><head><meta charset=\"UTF-8\"><style>"
        + "body { font-family: DejaVu Sans, sans-serif; font-size: 12px; }"
        + "h1 { font-size: 18px; margin: 0 0 4px; } .meta { color: #555; margin-bottom: 14px; }"
        + ".fields { margin-bottom: 16px; } .question { margin-bottom: 14px; page-break-inside: avoid; }"
        + ".option { margin-left: 18px; }"
        + "</style></head><body>";

    internal sealed record Question(string Text, IReadOnlyList<string> Options);

    [GeneratedRegex("[^A-Za-z0-9_-]+")]
    private static partial Regex FileNameRuns();

    public static string Html(string name, string? topic, string classCode, string className, IReadOnlyList<Question> questions)
    {
        ArgumentNullException.ThrowIfNull(questions);
        var html = new StringBuilder(Head);
        html.Append("<h1>").Append(Encode(name)).Append("</h1><div class=\"meta\">");
        if (!string.IsNullOrEmpty(topic) && topic != "0")
        {
            html.Append(Encode(topic)).Append(" &middot; ");
        }

        html.Append(Encode(classCode + " " + className)).Append("</div>");
        html.Append("<div class=\"fields\">Name: ______________________________ &nbsp; Date: ______________</div>");
        for (var i = 0; i < questions.Count; i++)
        {
            html.Append("<div class=\"question\"><div><b>").Append(i + 1).Append(".</b> ").Append(Encode(questions[i].Text)).Append("</div>");
            for (var j = 0; j < questions[i].Options.Count; j++)
            {
                html.Append("<div class=\"option\">").Append((char)('a' + j)).Append(") ").Append(Encode(questions[i].Options[j])).Append("</div>");
            }

            html.Append("</div>");
        }

        return html.Append("</body></html>").ToString();
    }

    /// <summary>PHP's file name: <c>MCQ_</c> and the quiz code with every run of characters other than letters, digits, underscore and hyphen made one underscore.</summary>
    public static string FileNameBase(string? code) => "MCQ_" + FileNameRuns().Replace(code ?? string.Empty, "_");

    private static string Encode(string text) => WebUtility.HtmlEncode(text);
}
