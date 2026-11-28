namespace Tsr.Search.Api.Domain;

/// <summary>
/// The settings and mappings of the Library indexes, written as tsr-web has them so a query and an index from either side fit each other (plan 3.4). Articles: <c>web/src/app/api/lib/reindex-service.ts</c> <c>ensureIndex</c>
/// (the index <c>tsr-articles</c>: one shard, no replica, the analyzer <c>multilingual_analyzer</c> = standard tokenizer, <c>html_strip</c>, lowercase, asciifolding).
/// </summary>
internal static class LibraryIndexMappings
{
    /// <summary>Lectures: <c>web/src/app/api/lib/lectures-index.ts</c> (the index <c>tsr-lectures</c>; the same settings as the articles; the transcript in <c>content</c>; the chapters nested; a 384-number cosine <c>dense_vector</c>, index_options flat: exact, which suits a corpus of about a thousand lectures).</summary>
    public const string Lectures =
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
              "search_phrases": { "type": "text", "analyzer": "multilingual_analyzer" },
              "key_points": { "type": "text", "analyzer": "multilingual_analyzer" },
              "tags": { "type": "keyword" },
              "language": { "type": "keyword" },
              "publishedDate": { "type": "date" },
              "durationSec": { "type": "integer" },
              "url": { "type": "keyword" },
              "chapters": {
                "type": "nested",
                "properties": {
                  "start_sec": { "type": "integer" },
                  "title": { "type": "text", "analyzer": "multilingual_analyzer" },
                  "summary": { "type": "text", "analyzer": "multilingual_analyzer" },
                  "url": { "type": "keyword" }
                }
              },
              "embedding": { "type": "dense_vector", "dims": 384, "index": true, "similarity": "cosine", "index_options": { "type": "flat" } },
              "indexed_at": { "type": "date" }
            }
          }
        }
        """;

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
