using System.Security.Cryptography;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The code members type to open a quiz. PHP's insert trigger <c>spot_quizzes_before_insert</c> made it: <c>LPAD(CONV(FLOOR(RAND()*POW(36,8)), 10, 36), 8, 0)</c>, that is 8 characters of base 36 (digits and UPPER-CASE letters),
/// drawn again while a quiz with that code exists. Here the draw is cryptographic (a code is a way into a class's quiz) and the same alphabet and length keep every code PHP made valid and every new one valid for PHP's readers.
/// </summary>
internal static class QuizCode
{
    public const int Length = 8;
    public const string Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    public static string Generate() => RandomNumberGenerator.GetString(Alphabet, Length);
}
