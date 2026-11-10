namespace Tsr.Host.Site;

/// <summary>The site's one stylesheet. Kept tiny on purpose: the spike is about composition, not design.</summary>
internal static class SiteStyle
{
    public const string Css = """
        body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 0 auto; padding: 0 1rem; line-height: 1.6; }
        header { display: flex; gap: 1.5rem; align-items: baseline; padding: 1rem 0; border-bottom: 1px solid #ddd; }
        header nav { display: flex; gap: 1rem; }
        footer { margin-top: 3rem; padding: 1rem 0; border-top: 1px solid #ddd; color: #666; font-size: 0.9rem; }
        """;
}
