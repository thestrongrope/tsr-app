namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>strnatcmp</c> (case sensitive, ASCII digits): "natural order", where a run of digits compares as a number. Port of PHP's strnatcmp_ex.</summary>
internal static class NaturalCompare
{
    public static int Compare(string a, string b)
    {
        ArgumentNullException.ThrowIfNull(a);
        ArgumentNullException.ThrowIfNull(b);
        if (a.Length == 0 || b.Length == 0)
        {
            return a.Length.CompareTo(b.Length);
        }

        int ap = 0, bp = 0;
        while (true)
        {
            var ca = At(a, ap);
            var cb = At(b, bp);
            while (ca == '0' && ap + 1 < a.Length && IsDigit(a[ap + 1]))
            {
                ca = a[++ap];
            }

            while (cb == '0' && bp + 1 < b.Length && IsDigit(b[bp + 1]))
            {
                cb = b[++bp];
            }

            while (IsSpace(ca))
            {
                ca = At(a, ++ap);
            }

            while (IsSpace(cb))
            {
                cb = At(b, ++bp);
            }

            if (IsDigit(ca) && IsDigit(cb))
            {
                var result = ca == '0' || cb == '0' ? CompareLeft(a, ref ap, b, ref bp) : CompareRight(a, ref ap, b, ref bp);
                if (result != 0)
                {
                    return result;
                }

                if (ap == a.Length && bp == b.Length)
                {
                    return 0;
                }

                if (ap == a.Length)
                {
                    return -1;
                }

                if (bp == b.Length)
                {
                    return 1;
                }

                ca = a[ap];
                cb = b[bp];
            }

            if (ca != cb)
            {
                return ca < cb ? -1 : 1;
            }

            ap++;
            bp++;
            if (ap >= a.Length && bp >= b.Length)
            {
                return 0;
            }

            if (ap >= a.Length)
            {
                return -1;
            }

            if (bp >= b.Length)
            {
                return 1;
            }
        }
    }

    // The longest run of digits wins; otherwise the first differing digit decides, but only once both runs are known to have the same length.
    private static int CompareRight(string a, ref int ap, string b, ref int bp)
    {
        var bias = 0;
        for (; ; ap++, bp++)
        {
            var aDigit = ap < a.Length && IsDigit(a[ap]);
            var bDigit = bp < b.Length && IsDigit(b[bp]);
            if (!aDigit && !bDigit)
            {
                return bias;
            }

            if (!aDigit)
            {
                return -1;
            }

            if (!bDigit)
            {
                return 1;
            }

            if (bias == 0 && a[ap] != b[bp])
            {
                bias = a[ap] < b[bp] ? -1 : 1;
            }
        }
    }

    // Two left-aligned numbers (a leading zero): the first differing digit wins.
    private static int CompareLeft(string a, ref int ap, string b, ref int bp)
    {
        for (; ; ap++, bp++)
        {
            var aDigit = ap < a.Length && IsDigit(a[ap]);
            var bDigit = bp < b.Length && IsDigit(b[bp]);
            if (!aDigit && !bDigit)
            {
                return 0;
            }

            if (!aDigit)
            {
                return -1;
            }

            if (!bDigit)
            {
                return 1;
            }

            if (a[ap] != b[bp])
            {
                return a[ap] < b[bp] ? -1 : 1;
            }
        }
    }

    private static char At(string text, int index) => index < text.Length ? text[index] : '\0';

    private static bool IsDigit(char c) => c is >= '0' and <= '9';

    private static bool IsSpace(char c) => c is ' ' or '\t' or '\n' or '\r' or '\v' or '\f';
}
