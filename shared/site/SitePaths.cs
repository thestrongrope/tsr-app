namespace Tsr.Shared.Site;

/// <summary>The one rule for "a path on this site", used wherever a build input becomes an address in a page.</summary>
public static class SitePaths
{
    /// <summary>
    /// True for one leading '/' followed by a character that is not '/' or a backslash, with no backslash, control character or white
    /// space anywhere (a browser reads a backslash as '/' and drops tabs and line breaks, so those would name another site). A scheme
    /// such as "https:" or "javascript:" never starts with '/', so it fails too.
    /// </summary>
    public static bool IsSitePath(string address) =>
        address.Length >= 2 && address[0] == '/' && address[1] != '/' && IsPlain(address);

    /// <summary>True when the address holds no backslash, control character or white space.</summary>
    public static bool IsPlain(string address) =>
        address.All(c => c != '\\' && !char.IsControl(c) && !char.IsWhiteSpace(c));
}
