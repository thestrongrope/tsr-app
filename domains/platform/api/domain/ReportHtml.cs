using System.Net;
using System.Text;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The page PHP gave Dompdf (<c>ReportExportModel::pdf</c>), word for word apart from the font: a title and, per section, a heading and a table.
/// Every value, the title and the headings included, is HTML-encoded, so a name or a reason a member typed cannot add markup, a script or a
/// link. The page refers to no outside resource (no font, image or stylesheet file).
/// </summary>
internal static class ReportHtml
{
    private const string Head =
        "<html><head><meta charset=\"UTF-8\"><style>"
        + "body { font-family: DejaVu Sans, sans-serif; font-size: 9px; }"
        + "h1 { font-size: 14px; } h2 { font-size: 11px; margin: 14px 0 4px; }"
        + "table { border-collapse: collapse; width: 100%; }"
        + "th, td { border: 1px solid #999; padding: 3px 5px; text-align: left; }"
        + "th { background: #e8f5f2; }"
        + "</style></head><body>";

    public static string Build(string title, IReadOnlyList<ReportSection> sections)
    {
        ArgumentNullException.ThrowIfNull(sections);
        var html = new StringBuilder(Head);
        html.Append("<h1>").Append(Encode(title)).Append("</h1>");
        foreach (var section in sections)
        {
            html.Append("<h2>").Append(Encode(section.Heading)).Append("</h2><table><tr>");
            foreach (var header in section.Headers)
            {
                html.Append("<th>").Append(Encode(header)).Append("</th>");
            }

            html.Append("</tr>");
            foreach (var row in section.Rows)
            {
                html.Append("<tr>");
                foreach (var value in row)
                {
                    html.Append("<td>").Append(Encode(ReportCell.Text(value))).Append("</td>");
                }

                html.Append("</tr>");
            }

            html.Append("</table>");
        }

        return html.Append("</body></html>").ToString();
    }

    private static string Encode(string text) => WebUtility.HtmlEncode(text);
}
