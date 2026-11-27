using Mizan.Application.Security;
using Mizan.Domain.Entities;
using Xunit;

namespace Mizan.Tests;

public sealed class AuthAndBaseCurrencyTests
{
    [Fact]
    public void Pbkdf2PasswordHashing_AndJwtIssuance_WorkDeterministically()
    {
        var svc = new PasswordAndTokenService();
        var hash = svc.HashPassword("MizanPilot#2026!");
        Assert.True(svc.VerifyPassword("MizanPilot#2026!", hash));
        Assert.False(svc.VerifyPassword("WrongPass#2026!", hash));

        var key = "MIZAN_TEST_SIGNING_KEY_AT_LEAST_32_BYTES_LONG_256BIT";
        var (token, exp) = svc.IssueJwtAccessToken(Guid.NewGuid(), "USR-100001", "owner@seha.local", key, "mizan.auth", "mizan.api");
        Assert.False(string.IsNullOrWhiteSpace(token));
        Assert.True(exp > DateTimeOffset.UtcNow);
    }

    [Fact]
    public void JournalLine_AutoPopulatesBaseDebitAndBaseCredit_MatchingMigration005Constraint()
    {
        var orgId = Guid.NewGuid();
        var entry = new JournalEntry
        {
            OrgId = orgId, IdempotencyKey = "BASE-MIRROR-1",
            Currency = "EUR", ExchangeRate = 1.0837m
        };
        entry.AddLine(new JournalLine { OrgId = orgId, AccountId = Guid.NewGuid(), Debit = 100.00m });
        entry.AddLine(new JournalLine { OrgId = orgId, AccountId = Guid.NewGuid(), Credit = 100.00m });
        entry.EnsureBalanced();

        Assert.Equal(108.3700m, entry.Lines[0].BaseDebit);
        Assert.Equal(0m, entry.Lines[0].BaseCredit);
        Assert.Equal(0m, entry.Lines[1].BaseDebit);
        Assert.Equal(108.3700m, entry.Lines[1].BaseCredit);
    }
}
