namespace Tsr.Search.Api.Domain;

/// <summary>The index settings and field types, identical to PHP's <c>SearchIndexModel::mapping()</c> (models/searchindex.php), so the query works against an index either side built.</summary>
internal static class SearchIndexMapping
{
    public const string Json = """
        {
          "settings": {
            "number_of_shards": 1,
            "number_of_replicas": 0,
            "analysis": {
              "filter": {
                "prefix_2_15": { "type": "edge_ngram", "min_gram": 2, "max_gram": 15 },
                "truncate_15": { "type": "truncate", "length": 15 }
              },
              "analyzer": {
                "name_prefix": { "type": "custom", "tokenizer": "standard", "filter": ["lowercase", "asciifolding", "arabic_normalization", "prefix_2_15"] },
                "name_search": { "type": "custom", "tokenizer": "standard", "filter": ["lowercase", "asciifolding", "arabic_normalization", "truncate_15"] }
              }
            }
          },
          "mappings": {
            "properties": {
              "kind": { "type": "keyword" },
              "id": { "type": "long" },
              "name": { "type": "text", "analyzer": "name_prefix", "search_analyzer": "name_search" },
              "gender": { "type": "integer" },
              "level": { "type": "keyword" },
              "level_id": { "type": "integer" },
              "class_ids": { "type": "long" },
              "class_genders": { "type": "integer" },
              "token": { "type": "long" }
            }
          }
        }
        """;
}
