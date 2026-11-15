using System.Globalization;
using System.Text;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Domain;

/// <summary>The published content of one content directory, as rows ready to store. A draft is never in it.</summary>
internal sealed record ContentSet(IReadOnlyList<PublishedArticle> Articles, IReadOnlyList<Category> Categories, IReadOnlyList<Publication> Publications);

/// <summary>
/// Reads one content directory in the layout of the website's content files: <c>articles/*.md</c>, <c>categories/*.md</c> and <c>pages/tsr-publications.md</c>.
/// The rule for how a file is read is tsr-web's <c>web/src/lib/markdown.ts</c> (gray-matter): an article's slug is its front matter <c>slug</c>, a category's slug is its file name.
/// Stricter than tsr-web in one way: a published article that cannot be stored (no slug, title or date; a value of the wrong kind or too long) fails the whole read,
/// so the last complete set stays. A failure is a fixed phrase and a file name at most, never file content.
/// The files are untrusted input: every bound below is a failure, never a truncation, and any exception ends in a failure that names its type at most.
/// How front matter is read, and what of YAML is refused: <see cref="FrontMatter"/>.
/// </summary>
internal static class ContentFiles
{
    public const int MaxFiles = 20_000;

    public const long MaxFileBytes = 5 * 1024 * 1024;

    public const long MaxTotalBytes = 200L * 1024 * 1024;

    public const int MaxFrontMatterBytes = 64 * 1024;

    public const int MaxBodyCharacters = 100_000;

    public const int MaxSlugLength = 255;

    /// <summary>The most tags, and the most categories, on one article.</summary>
    public const int MaxLabels = 50;

    /// <summary>The longest tag or category.</summary>
    public const int MaxLabelLength = 200;

    public const string NoDirectory = "no content directory";

    public const string TookTooLong = "content read took too long";

    /// <summary>The budget for one whole read, checked between files (one file is bounded by its size bounds).</summary>
    public static readonly TimeSpan MaxReadTime = TimeSpan.FromMinutes(2);

    private const string Extension = ".md";

    private const string PublicationsPage = "tsr-publications.md";

    private const int DefaultOrder = 999;

    // The three shapes found in the files: with a zone and milliseconds, with microseconds and no zone, plain seconds.
    private static readonly string[] DateShapes = ["yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK", "yyyy-MM-dd'T'HH:mm:ssK"];

    /// <summary>
    /// The parsed set, or why it could not be read. Stops with <see cref="OperationCanceledException"/> only when <paramref name="ct"/> is cancelled (the host is stopping);
    /// every other exception, expected or not, is a failure. <paramref name="clock"/> times the read.
    /// </summary>
    public static Result<ContentSet> Read(string? directory, TimeProvider clock, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(directory) || !Directory.Exists(directory))
        {
            return Result.Fail<ContentSet>(NoDirectory);
        }

        var progress = new Progress(clock, ct);
        try
        {
            progress.Start();
            return ReadSet(directory, progress);
        }
        catch (Exception e) when (progress.File is null && e is IOException or UnauthorizedAccessException)
        {
            return Result.Fail<ContentSet>("cannot list the content directory");
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            // The type name only: an exception's message can quote the file's text.
            var kind = e.GetType().Name;
            return Result.Fail<ContentSet>(progress.File is null ? $"content read failed: {kind}" : $"content read failed: {kind} in {progress.File}");
        }
    }

    private static Result<ContentSet> ReadSet(string directory, Progress progress)
    {
        var linkedFolder = ((string[])["articles", "categories", "pages"]).FirstOrDefault(name => IsLink(new DirectoryInfo(Path.Combine(directory, name))));
        if (linkedFolder is not null)
        {
            return Result.Fail<ContentSet>(LinkRefused(linkedFolder));
        }

        var articleFiles = MarkdownFiles(Path.Combine(directory, "articles"));
        var categoryFiles = MarkdownFiles(Path.Combine(directory, "categories"));
        var page = new FileInfo(Path.Combine(directory, "pages", PublicationsPage));
        // A link that points nowhere does not "exist", and is still refused below.
        FileInfo[] pages = page.Exists || IsLink(page) ? [page] : [];
        var refused = Refused([.. articleFiles, .. categoryFiles, .. pages]);
        if (refused is not null)
        {
            return Result.Fail<ContentSet>(refused);
        }

        var articles = Articles(articleFiles, progress);
        if (!articles.IsSuccess)
        {
            return Result.Fail<ContentSet>(articles.Error!);
        }

        var categories = Categories(categoryFiles, progress);
        if (!categories.IsSuccess)
        {
            return Result.Fail<ContentSet>(categories.Error!);
        }

        var publications = Publications(page, progress);
        return publications.IsSuccess
            ? Result.Ok(new ContentSet(articles.Value!, categories.Value!, publications.Value!))
            : Result.Fail<ContentSet>(publications.Error!);
    }

    /// <summary>
    /// The <c>.md</c> files of one folder in name order, and every symbolic link, whatever its name
    /// (so the caller can refuse it); one more than the bound at most, so the caller can tell "too many" without listing them all.
    /// </summary>
    private static List<FileInfo> MarkdownFiles(string folder)
    {
        if (!Directory.Exists(folder))
        {
            return [];
        }

        return
        [
            .. new DirectoryInfo(folder).EnumerateFileSystemInfos()
                .Where(entry => IsLink(entry) || (entry is FileInfo && entry.Name.EndsWith(Extension, StringComparison.Ordinal)))
                .Take(MaxFiles + 1)
                .Select(entry => new FileInfo(entry.FullName))
                .OrderBy(file => file.Name, StringComparer.Ordinal),
        ];
    }

    private static bool IsLink(FileSystemInfo entry) => entry.LinkTarget is not null;

    private static string LinkRefused(string name) => $"symbolic link refused: {name}";

    /// <summary>
    /// The bounds over the whole listing, checked before any file is opened: the count, no symbolic link, the total size.
    /// A named pipe or device under the content directory is not detected (the directory is a read-only mount of files from git), and reading one would block the refresh.
    /// </summary>
    private static string? Refused(List<FileInfo> files)
    {
        if (files.Count > MaxFiles)
        {
            return "too many files";
        }

        var link = files.FirstOrDefault(IsLink);
        if (link is not null)
        {
            return LinkRefused(link.Name);
        }

        return files.Sum(file => file.Length) > MaxTotalBytes ? "content too large" : null;
    }

    private static Result<List<PublishedArticle>> Articles(List<FileInfo> files, Progress progress)
    {
        var articles = new List<PublishedArticle>();
        var slugs = new HashSet<string>(StringComparer.Ordinal);
        foreach (var file in files)
        {
            var loaded = Load(file, progress);
            if (!loaded.IsSuccess)
            {
                return Result.Fail<List<PublishedArticle>>(loaded.Error!);
            }

            var fields = loaded.Value!.Fields;
            if (fields.Text("status") is not ("publish" or "published"))
            {
                continue;
            }

            // The renderer's time grows faster than the text, and it cannot be cancelled: the bound is what keeps one file short.
            if (loaded.Value.Body.Length > MaxBodyCharacters)
            {
                return Result.Fail<List<PublishedArticle>>($"body too long: {file.Name}");
            }

            var article = Article(fields, loaded.Value.Body);
            if (fields.Failure is not null)
            {
                return Result.Fail<List<PublishedArticle>>(fields.Failure);
            }

            // Both are unique in the table: the slug as written, and the decoded one a request path is matched against.
            if (!slugs.Add(article.Slug) || (article.SlugDecoded != article.Slug && !slugs.Add(article.SlugDecoded)))
            {
                return Result.Fail<List<PublishedArticle>>($"duplicate slug: {file.Name}");
            }

            articles.Add(article);
        }

        return Result.Ok(articles);
    }

    private static PublishedArticle Article(Fields fields, string body)
    {
        var slug = fields.Required("slug", MaxSlugLength);
        var published = fields.Date("publishedDate") ?? fields.Missing<(string, DateTimeOffset)>("publishedDate");
        var modified = fields.Date("modifiedDate");
        return new PublishedArticle
        {
            Slug = slug,
            SlugDecoded = fields.Slug("slug", slug),
            LegacyId = fields.Int("id"),
            Title = fields.Required("title", 500),
            Excerpt = fields.Text("excerpt"),
            BodyMarkdown = body,
            BodyHtml = ArticleHtml.ToHtml(body),
            PublishedAt = published.At,
            PublishedDateText = published.Text,
            ModifiedAt = modified?.At,
            ModifiedDateText = modified?.Text,
            Author = fields.Filled("author", 100) ?? "admin",
            Language = fields.Filled("language", 10) ?? "en",
            ReadingMinutes = ArticleHtml.ReadingMinutes(body),
            Categories = fields.List("categories", MaxLabels, MaxLabelLength),
            Tags = fields.List("tags", MaxLabels, MaxLabelLength),
        };
    }

    private static Result<List<Category>> Categories(List<FileInfo> files, Progress progress)
    {
        var categories = new List<Category>();
        foreach (var file in files)
        {
            var loaded = Load(file, progress);
            if (!loaded.IsSuccess)
            {
                return Result.Fail<List<Category>>(loaded.Error!);
            }

            var fields = loaded.Value!.Fields;
            var slug = file.Name[..^Extension.Length];
            fields.Slug("file name", slug);
            var order = fields.Int("order") ?? 0;
            var category = new Category
            {
                Slug = slug,
                Title = fields.Filled("title", 255) ?? slug,
                Description = fields.Text("description"),
                SortOrder = order == 0 ? DefaultOrder : order,
                ParentSlug = fields.Filled("parent", 255),
            };
            if (fields.Failure is not null)
            {
                return Result.Fail<List<Category>>(fields.Failure);
            }

            categories.Add(category);
        }

        return Result.Ok(categories);
    }

    /// <summary>tsr-web <c>parsePublications</c> (<c>api/v1/publications/route.ts</c>): the page's <c>publications</c> list; an entry with neither a file nor a reading address is dropped.</summary>
    private static Result<List<Publication>> Publications(FileInfo page, Progress progress)
    {
        if (!page.Exists)
        {
            return Result.Ok(new List<Publication>());
        }

        var loaded = Load(page, progress);
        if (!loaded.IsSuccess)
        {
            return Result.Fail<List<Publication>>(loaded.Error!);
        }

        var publications = new List<Publication>();
        if (loaded.Value!.Fields.Node("publications") is not FrontMatter.Sequence entries)
        {
            return Result.Ok(publications);
        }

        for (var index = 0; index < entries.Items.Count; index++)
        {
            if (entries.Items[index] is not FrontMatter.Mapping entry)
            {
                continue;
            }

            var fields = new Fields(entry.Fields, page.Name);
            var publication = Publication(fields, index + 1);
            if (fields.Failure is not null)
            {
                return Result.Fail<List<Publication>>(fields.Failure);
            }

            if (publication.File is not null || publication.ReadOnlineUrl is not null)
            {
                publications.Add(publication);
            }
        }

        return Result.Ok(publications);
    }

    private static Publication Publication(Fields fields, int position) => new()
    {
        Position = position,
        Title = fields.Text("title", 500) ?? "Untitled publication",
        Summary = fields.Filled("summary"),
        Type = fields.Filled("type", 50),
        Size = fields.Filled("size", 50),
        Updated = fields.Filled("updated", 50),
        Language = fields.Filled("language", 50),
        File = fields.Link("file", 500),
        ReadOnlineUrl = fields.Link("readOnlineUrl", 500),
        DownloadOnly = fields.IsTrue("downloadOnly"),
    };

    private static Result<Loaded> Load(FileInfo file, Progress progress)
    {
        if (progress.Next(file) is { } late)
        {
            return Result.Fail<Loaded>(late);
        }

        var read = Text(file);
        if (!read.IsSuccess)
        {
            return Result.Fail<Loaded>(read.Error!);
        }

        var (yaml, body) = Split(read.Value!);
        if (Encoding.UTF8.GetByteCount(yaml) > MaxFrontMatterBytes)
        {
            return Result.Fail<Loaded>($"front matter too large: {file.Name}");
        }

        var front = FrontMatter.Read(yaml);
        return front.IsSuccess
            ? Result.Ok(new Loaded(new Fields(front.Value!, file.Name), body))
            : Result.Fail<Loaded>($"{front.Error}: {file.Name}");
    }

    /// <summary>The file's text. PostgreSQL stores no NUL character in a text, so one anywhere in the file is a failure here, not a failed insert on every tick.</summary>
    private static Result<string> Text(FileInfo file)
    {
        string text;
        try
        {
            if (file.Length > MaxFileBytes)
            {
                return Result.Fail<string>($"file too large: {file.Name}");
            }

            text = File.ReadAllText(file.FullName);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return Result.Fail<string>($"cannot read file: {file.Name}");
        }

        return text.Contains('\0', StringComparison.Ordinal) ? Result.Fail<string>($"NUL character in file: {file.Name}") : Result.Ok(text);
    }

    /// <summary>gray-matter's split: front matter between a first line <c>---</c> and the next line starting <c>---</c>; the body is what follows, less one line break. No front matter: all body.</summary>
    private static (string Yaml, string Body) Split(string text)
    {
        const string Fence = "---";
        if (!text.StartsWith(Fence, StringComparison.Ordinal) || (text.Length > Fence.Length && text[Fence.Length] == '-'))
        {
            return (string.Empty, text);
        }

        var rest = text[Fence.Length..];
        var close = rest.IndexOf("\n" + Fence, StringComparison.Ordinal);
        if (close < 0)
        {
            return (rest, string.Empty);
        }

        var body = rest[(close + 1 + Fence.Length)..];
        if (body.StartsWith('\r'))
        {
            body = body[1..];
        }

        return (rest[..close], body.StartsWith('\n') ? body[1..] : body);
    }

    private sealed record Loaded(Fields Fields, string Body);

    /// <summary>Where one read is: the file in hand (for a failure's cause), and the two checks made between files, the host stopping and the time budget.</summary>
    private sealed class Progress(TimeProvider clock, CancellationToken ct)
    {
        private long started;

        public string? File { get; private set; }

        public void Start() => started = clock.GetTimestamp();

        /// <summary>Moves to the next file; the failure when the read has run out of time.</summary>
        public string? Next(FileInfo file)
        {
            ct.ThrowIfCancellationRequested();
            File = file.Name;
            return clock.GetElapsedTime(started) > MaxReadTime ? TookTooLong : null;
        }
    }

    /// <summary>
    /// One file's front matter, each field read by name. A field of the wrong kind sets <see cref="Failure"/> (the first one wins) and the read goes on with an empty value,
    /// so the caller builds its row in one expression and checks <see cref="Failure"/> once.
    /// </summary>
    private sealed class Fields(Dictionary<string, FrontMatter.Value> named, string fileName)
    {
        private const string BadCharacter = "bad character in";

        private const string TooLong = "value too long in";

        public string? Failure { get; private set; }

        public FrontMatter.Value? Node(string name) => named.GetValueOrDefault(name);

        /// <summary>A scalar's text; null when the field is absent or YAML's null.</summary>
        public string? Text(string name, int maxLength = int.MaxValue)
        {
            var node = Node(name);
            if (node is null)
            {
                return null;
            }

            if (node is not FrontMatter.Text scalar)
            {
                return Fail<string?>("bad value in", name);
            }

            if (scalar.IsNull)
            {
                return null;
            }

            var text = scalar.Content;
            if (HasNul(text))
            {
                return Fail<string?>(BadCharacter, name);
            }

            return text.Length > maxLength ? Fail<string?>(TooLong, name) : text;
        }

        /// <summary>As <see cref="Text"/>, with an empty text as null too (what JavaScript's <c>||</c> and truth test do in tsr-web).</summary>
        public string? Filled(string name, int maxLength = int.MaxValue) => Text(name, maxLength) is { Length: > 0 } text ? text : null;

        public string Required(string name, int maxLength = int.MaxValue) => Filled(name, maxLength) ?? Missing<string>(name) ?? string.Empty;

        public T? Missing<T>(string name) => Fail<T>("missing", name);

        public int? Int(string name)
        {
            var text = Filled(name);
            if (text is null)
            {
                return null;
            }

            return int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out var number) ? number : Fail<int?>("bad number in", name);
        }

        /// <summary>The file's own date string and the instant it names; a date without a zone is UTC.</summary>
        public (string Text, DateTimeOffset At)? Date(string name)
        {
            var text = Filled(name, 40);
            if (text is null)
            {
                return null;
            }

            var styles = DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal;
            return DateTimeOffset.TryParseExact(text, DateShapes, CultureInfo.InvariantCulture, styles, out var at)
                ? (text, at)
                : Fail<(string, DateTimeOffset)?>("bad date in", name);
        }

        /// <summary>A list of texts in file order; empty when the field is absent or null. More than <paramref name="maxCount"/> texts, or one longer than <paramref name="maxLength"/>, is a failure.</summary>
        public string[] List(string name, int maxCount, int maxLength)
        {
            var node = Node(name);
            if (node is null or FrontMatter.Text { IsNull: true })
            {
                return [];
            }

            if (node is not FrontMatter.Sequence sequence || sequence.Items.Any(item => item is not FrontMatter.Text))
            {
                return Fail<string[]>("bad list in", name) ?? [];
            }

            if (sequence.Items.Count > maxCount)
            {
                return Fail<string[]>("too many values in", name) ?? [];
            }

            string[] texts = [.. sequence.Items.Cast<FrontMatter.Text>().Select(item => item.Content)];
            if (texts.Any(HasNul))
            {
                return Fail<string[]>(BadCharacter, name) ?? [];
            }

            return texts.Any(text => text.Length > maxLength) ? Fail<string[]>(TooLong, name) ?? [] : texts;
        }

        /// <summary>YAML's true, unquoted (tsr-web: <c>=== true</c>).</summary>
        public bool IsTrue(string name) => Node(name) is FrontMatter.Text { IsTrue: true };

        /// <summary><paramref name="text"/> percent-decoded. A text without a NUL character can decode to one (<c>%00</c>), and PostgreSQL stores none: a failure here.</summary>
        public string PercentDecoded(string name, string text)
        {
            var decoded = Uri.UnescapeDataString(text);
            return HasNul(decoded) ? Fail<string>(BadCharacter, name) ?? string.Empty : decoded;
        }

        /// <summary>
        /// <paramref name="text"/> percent-decoded, as a request path is matched against it. A failure when the decoded slug could not be one path segment:
        /// empty, <c>.</c> or <c>..</c>, or holding a slash, a backslash, white space or a control character.
        /// </summary>
        public string Slug(string name, string text)
        {
            var decoded = PercentDecoded(name, text);
            var isSegment = decoded is not ("" or "." or "..") && !decoded.Any(c => c is '/' or '\\' || IsSpaceOrControl(c));
            return isSegment ? decoded : Fail<string>("bad slug in", name) ?? string.Empty;
        }

        /// <summary>
        /// As <see cref="Filled"/>, for an address a reader's app or browser opens: site-relative (one leading <c>/</c>; <c>//host</c> and <c>/\host</c> name another site) or <c>http</c> or <c>https</c>,
        /// with no white space or control character anywhere (a browser drops a tab or a line break, so <c>/</c>, a tab, <c>/host</c> opens <c>//host</c>). Anything else is a failure.
        /// </summary>
        public string? Link(string name, int maxLength)
        {
            var text = Filled(name, maxLength);
            var allowed = text is null || (!text.Any(IsSpaceOrControl) && (IsSiteRelative(text) || IsHttp(text)));
            return allowed ? text : Fail<string?>("bad link in", name);
        }

        private static bool IsSpaceOrControl(char c) => char.IsWhiteSpace(c) || char.IsControl(c);

        private static bool IsSiteRelative(string link) => link.StartsWith('/') && (link.Length == 1 || link[1] is not ('/' or '\\'));

        private static bool IsHttp(string link) =>
            link.StartsWith("http://", StringComparison.OrdinalIgnoreCase) || link.StartsWith("https://", StringComparison.OrdinalIgnoreCase);

        /// <summary>A quoted YAML text can spell a NUL character as an escape, so the file holds none and the value does.</summary>
        private static bool HasNul(string text) => text.Contains('\0', StringComparison.Ordinal);

        private T? Fail<T>(string phrase, string name)
        {
            Failure ??= $"{phrase} {name}: {fileName}";
            return default;
        }
    }
}
