using System.Globalization;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The lecture search settings, all optional (the API starts without them, SRCH-Q6): <c>TSR_EMBEDDINGS_URL</c> (the embedding service; empty or not an http(s) address: none), <c>TSR_LECTURES_SEMANTIC_WEIGHT</c> (a number above 0 switches the meaning layer on; 0, unset or anything
/// else leaves it off; tsr-web's <c>LECTURES_SEMANTIC_WEIGHT</c>, 0.25 in the compose files, the evaluated value) and <c>TSR_LECTURES_FILE</c> (the lecture data the feed indexes). The keyword weight (1), the embedding timeout (1.5 s) and the rate limits stay constants.
/// </summary>
internal sealed record LectureSettings(Uri? EmbeddingsUrl, double SemanticWeight, string? LecturesFile)
{
    public const string EmbeddingsUrlKey = "TSR_EMBEDDINGS_URL";

    public const string SemanticWeightKey = "TSR_LECTURES_SEMANTIC_WEIGHT";

    public const string LecturesFileKey = "TSR_LECTURES_FILE";

    /// <summary>The weight of the keyword ranking in the fusion (tsr-web <c>LECTURES_BM25_WEIGHT</c>, which nobody sets).</summary>
    public const double KeywordWeight = 1.0;

    /// <summary>The meaning layer is on: a weight above 0 and a service to ask.</summary>
    public bool SemanticEnabled => SemanticWeight > 0 && EmbeddingsUrl is not null;

    public static LectureSettings From(string? embeddingsUrl, string? semanticWeight, string? lecturesFile) =>
        new(
            Uri.TryCreate(embeddingsUrl, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https" ? uri : null,
            double.TryParse(semanticWeight, NumberStyles.Float, CultureInfo.InvariantCulture, out var weight) && double.IsFinite(weight) && weight > 0 ? weight : 0,
            string.IsNullOrWhiteSpace(lecturesFile) ? null : lecturesFile);
}
