using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>The words of one language of the Self-reflection page: the present website's translations.ts, as self-reflection.json holds it.</summary>
public sealed record Translation
{
    public required string Dir { get; init; }
    public required string Title { get; init; }
    public required string ResetButton { get; init; }
    public required NoticeText Notice { get; init; }
    public required InstructionsText Instructions { get; init; }
    public required Section1Text Section1 { get; init; }
    public required Section2Text Section2 { get; init; }
    public required Section3Text Section3 { get; init; }
    public required Section4Text Section4 { get; init; }
    public required Section5Text Section5 { get; init; }
    public required Section6Text Section6 { get; init; }
    public required ScoreText Score { get; init; }
    public required ReviewRuleText ReviewRule { get; init; }
    public required FinalReminderText FinalReminder { get; init; }
    public required StickyText Sticky { get; init; }
    public required string LanguageSelect { get; init; }
}

public sealed record NoticeText(string Line1, string Line2, string NotSaved);

public sealed record InstructionsText(string Title, IReadOnlyList<InstructionItem> Items);

/// <summary>One instruction; <c>{bold}</c> in the text marks where the bold word goes (absent: the whole text is plain).</summary>
public sealed record InstructionItem(string? Bold, string Text);

public sealed record Section1Text(string Title, string Subtitle, IReadOnlyList<string> Questions, string Yes, string No, string ScoringNote, string Reflection, string ReflectionPlaceholder);

public sealed record ChoiceQuestion(string Label, IReadOnlyList<string> Options);

public sealed record Section2Text(string Title, string Subtitle, IReadOnlyList<ChoiceQuestion> Questions, string ScoringNote, string Reflection, string ReflectionPlaceholder);

public sealed record TextQuestion(string Label, string Placeholder);

public sealed record Section3Text(string Title, string Subtitle, string Instruction, IReadOnlyList<TextQuestion> Questions);

public sealed record Levels(string Weak, string Inconsistent, string Strong);

public sealed record Section4Text(string Title, string Subtitle, IReadOnlyList<string> Traits, Levels Levels, string ScoringNote, string Reflection, string ReflectionPlaceholder);

public sealed record Section5Text(string Title, string Subtitle, IReadOnlyList<string> Options, string Other, string OtherPlaceholder, string PlanLabel, string PlanPlaceholder, string ScoringNote);

public sealed record Section6Text(string Title, string Subtitle, string Instruction, string Prompt, string Placeholder);

public sealed record RangeText(string Range, string Label);

public sealed record ScoreText(string Title, IReadOnlyList<RangeText> Ranges, string Important, string FocusArea);

public sealed record ReviewRuleText(string Title, string Text, string Quote);

public sealed record FinalReminderText(string Title, IReadOnlyList<string> Items, string Arabic, string ArabicMeaning);

public sealed record StickyText(string Conscious, string Sincere, string Misaligned, string Wakeup, string Focus);

/// <summary>
/// The Self-reflection pages (/self-reflection/en, /ur, /gu and the entry /self-reflection). The words are self-reflection.json, copied from the
/// present website without a change; the rules of what is written (the section names, their cut for the sticky bar, the option lists the script
/// maps saved answers with, the class sets) are here, and the script (hosts/site/wwwroot/self-reflection.js) only scores, saves and shows.
/// </summary>
public static partial class SelfReflection
{
    private const string SiteName = "The Strong Rope";
    private const string ResourceName = "self-reflection.json";

    /// <summary>The page's script, a file of the site host.</summary>
    public const string ScriptFile = "/self-reflection.js";

    /// <summary>The language order everywhere: the pages, the option lists handed to the script.</summary>
    public static readonly IReadOnlyList<string> Languages = ["en", "ur", "gu"];

    /// <summary>The present page asks in English on all three pages (page.tsx), so this text is not in translations.ts.</summary>
    public const string ConfirmReset = "Are you sure you want to reset all your answers?";

    /// <summary>The sticky bar shows at most this many characters of a section's name, then "...".</summary>
    private const int StickyNameLength = 15;

    public const string CheckOn = "bg-emerald-700 text-white";
    public const string CheckOff = "bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-600 text-gray-700 dark:text-gray-300";
    public const string ChoiceOn = "bg-emerald-700 text-white border-emerald-700";
    public const string ChoiceOff = "bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-600 text-gray-700 dark:text-gray-300";
    public const string StepOn = "bg-emerald-100 dark:bg-emerald-900/30 border-2 border-emerald-500";
    public const string StepOff = "bg-gray-100 dark:bg-gray-700 border-2 border-transparent hover:bg-gray-200 dark:hover:bg-gray-600";
    public const string OtherOff = "bg-gray-100 dark:bg-gray-700 border-2 border-transparent";
    public const string RadioOn = "border-emerald-700 bg-emerald-700";
    public const string RadioOff = "border-gray-400 dark:border-gray-500";
    public const string RangeOn = "bg-white/30 ring-2 ring-white";
    public const string RangeOff = "bg-white/15";
    public const string LinkOn = "bg-emerald-700 text-white";
    public const string LinkOff = "bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300";

    public const string RowReverse = "flex-row-reverse";
    public const string ItemPadRtl = "pr-5";
    public const string ItemPadLtr = "pl-5";
    public const string BulletRtl = "right-0";
    public const string BulletLtr = "left-0";
    public const string AlignRtl = "text-right";
    public const string AlignLtr = "text-left";

    /// <summary>Every class this page writes from C# (the stylesheet test reads this list, as it reads ArticleBody.AllClasses).</summary>
    public static readonly IReadOnlyList<string> AllClasses =
    [
        CheckOn, CheckOff, ChoiceOn, ChoiceOff, StepOn, StepOff, OtherOff, RadioOn, RadioOff, RangeOn, RangeOff, LinkOn, LinkOff,
        RowReverse, ItemPadRtl, ItemPadLtr, BulletRtl, BulletLtr, AlignRtl, AlignLtr,
    ];

    /// <summary>The section number and its label in front of a title, in any of the three languages (page.tsx's replace).</summary>
    [GeneratedRegex(@"SECTION \d+: |سیکشن \d+: |વિભાગ \d+: ")]
    private static partial Regex SectionNumber();

    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true };

    private static readonly Lazy<IReadOnlyDictionary<string, Translation>> Loaded = new(Load);

    /// <summary>The three languages' words, by language code. A missing or empty key stops the build.</summary>
    public static IReadOnlyDictionary<string, Translation> Translations => Loaded.Value;

    private static Dictionary<string, Translation> Load()
    {
        using var stream = typeof(SelfReflection).Assembly.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException($"The embedded file {ResourceName} is missing from the content site assembly.");
        return JsonSerializer.Deserialize<Dictionary<string, Translation>>(stream, Options)
            ?? throw new InvalidOperationException($"{ResourceName} holds no translations.");
    }

    /// <summary>A section's title without "SECTION 1: " (the name of the weakest section).</summary>
    public static string SectionName(string title) => SectionNumber().Replace(title, "");

    /// <summary>The name the sticky bar shows: the first 15 characters and "..." when longer.</summary>
    public static string StickyName(string name) =>
        name.Length > StickyNameLength ? string.Concat(name.AsSpan(0, StickyNameLength), "...") : name;

    /// <summary>
    /// Section 2's option words of the three languages, question by question, as JSON for the script: it maps a saved answer, in the words of
    /// whichever language it was saved in, to the option's position.
    /// </summary>
    public static string OptionLists() =>
        JsonSerializer.Serialize(Languages.Select(language =>
            Translations[language].Section2.Questions.Select(question => question.Options)));

    public static IReadOnlyList<SitePage> Pages()
    {
        var pages = Languages.Select(language => new SitePage(
            $"/self-reflection/{language}/", SiteName, typeof(SelfReflectionPage),
            new Dictionary<string, object?> { ["Language"] = language },
            Files: null, Script: ScriptFile)).ToList();
        pages.Insert(0, new SitePage("/self-reflection/", SiteName, typeof(SelfReflectionEntryPage),
            new Dictionary<string, object?>(), RefreshTo: "/self-reflection/en/"));
        return pages;
    }
}
