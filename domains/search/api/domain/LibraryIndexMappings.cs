namespace Tsr.Search.Api.Domain;

/// <summary>
/// The settings and mappings of the Library indexes, written as tsr-web has them so a query and an index from either side fit each other (plan 3.4). Articles: <c>web/src/app/api/lib/reindex-service.ts</c> <c>ensureIndex</c>
/// (the index <c>tsr-articles</c>: one shard, no replica, the analyzer <c>multilingual_analyzer</c> = standard tokenizer, <c>html_strip</c>, lowercase, asciifolding).
/// </summary>
internal static class LibraryIndexMappings
{
    public const string Articles =
        """
        {
          "settings": {
            "number_of_shards": 1,
            "number_of_replicas": 0,
            "analysis": {
              "analyzer": {
                "multilingual_analyzer": {
                  "type": "custom",
                  "tokenizer": "standard",
                  "char_filter": ["html_strip"],
                  "filter": ["lowercase", "asciifolding"]
                }
              }
            }
          },
          "mappings": {
            "properties": {
              "slug": { "type": "keyword" },
              "title": { "type": "text", "analyzer": "multilingual_analyzer", "fields": { "keyword": { "type": "keyword" } } },
              "excerpt": { "type": "text", "analyzer": "multilingual_analyzer" },
              "content": { "type": "text", "analyzer": "multilingual_analyzer" },
              "categories": { "type": "keyword" },
              "tags": { "type": "keyword" },
              "author": { "type": "keyword" },
              "language": { "type": "keyword" },
              "publishedDate": { "type": "date" },
              "modifiedDate": { "type": "date" },
              "status": { "type": "keyword" },
              "indexed_at": { "type": "date" }
            }
          }
        }
        """;
}
