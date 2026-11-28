using Elastic.Transport;
using HttpMethod = Elastic.Transport.HttpMethod;

namespace Tsr.Search.Api.Domain;

/// <summary>The raw search of the Library indexes (<see cref="ILibraryIndex"/>): a search body sent as plain JSON and the answer returned as text. Ensure, list and bulk are the writer's, given an index name.</summary>
internal sealed partial class ElasticSearchIndex
{
    // The client's own search timeout (5 seconds, set where the client is built): a slow engine makes the route fall back, not wait.
    private static readonly TimeSpan SearchTimeout = TimeSpan.FromSeconds(5);

    public async Task<string> SearchAsync(string index, string body, CancellationToken ct)
    {
        var response = await SendAsync(HttpMethod.POST, "/" + index + "/_search", PostData.String(body), JsonType, ct, SearchTimeout);
        Require(response);
        return response.Body;
    }
}
