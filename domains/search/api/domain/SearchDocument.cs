using System.Net;
using System.Text.Json.Nodes;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// One document of the index <c>tsr-search</c> as the feed writes it (PHP models/searchindex.php <c>doc</c>): every field is always present, empty or 0 where a kind has no use for it.
/// <see cref="Id"/> is the record's id (a class id, a member token, a guide's level id); the index id is <see cref="DocId"/>.
/// </summary>
internal sealed record SearchDocument(
    string Kind,
    long Id,
    string Name,
    int Gender,
    string Level,
    int LevelId,
    IReadOnlyList<long> ClassIds,
    IReadOnlyList<int> ClassGenders,
    long Token)
{
    public const string Class = "class";
    public const string Teacher = "teacher";
    public const string Guide = "guide";
    public const string Student = "student";
    public const string Subscriber = "subscriber";

    /// <summary>The index id, <c>"&lt;kind&gt;:&lt;id&gt;"</c> (PHP docId).</summary>
    public string DocId => Kind + ":" + Id;

    /// <summary>The webapp stores some names HTML-escaped (<c>Raza&amp;#039;s</c>); the index holds what a person types (PHP <c>plain</c>).</summary>
    public static string Plain(string text) => WebUtility.HtmlDecode(text);

    /// <summary>1 for <c>1</c> or <c>Male</c>, 2 for <c>2</c> or <c>Female</c>, 0 otherwise (PHP genderOf).</summary>
    public static int GenderOf(string? value) => value switch
    {
        "1" or "Male" => 1,
        "2" or "Female" => 2,
        _ => 0,
    };

    public static SearchDocument ForClass(long id, string code, int gender, int levelId, string levelName) =>
        new(Class, id, Plain(code), gender, levelName, levelId, [id], [gender], 0);

    public static SearchDocument ForTeacher(long token, string name, int gender) =>
        new(Teacher, token, Plain(name), gender, string.Empty, 0, [], [], token);

    public static SearchDocument ForGuide(long levelId, string levelName) =>
        new(Guide, levelId, levelName + " guide", 0, levelName, (int)levelId, [], [], 0);

    public static SearchDocument ForStudent(long token, string name, int gender, IReadOnlyList<long> classIds, IReadOnlyList<int> classGenders) =>
        new(Student, token, Plain(name), gender, string.Empty, 0, classIds, classGenders, token);

    public static SearchDocument ForSubscriber(long token, string name, int gender) =>
        new(Subscriber, token, Plain(name), gender, string.Empty, 0, [], [], token);

    /// <summary>The JSON PHP's <c>json_encode</c> writes for the document: the same fields in the same order.</summary>
    public JsonObject ToJson() => new()
    {
        ["kind"] = Kind,
        ["id"] = Id,
        ["name"] = Name,
        ["gender"] = Gender,
        ["level"] = Level,
        ["level_id"] = LevelId,
        ["class_ids"] = new JsonArray(ClassIds.Select(id => (JsonNode?)JsonValue.Create(id)).ToArray()),
        ["class_genders"] = new JsonArray(ClassGenders.Select(g => (JsonNode?)JsonValue.Create(g)).ToArray()),
        ["token"] = Token,
    };
}
