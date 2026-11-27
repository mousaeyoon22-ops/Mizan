using Mizan.Application.Services;
using Mizan.Domain.Entities;
using Xunit;

namespace Mizan.Tests;

public sealed class SecurityAndIdempotencyTests
{
    [Fact]
    public void CrossTenantLineInjection_ThrowsUnauthorizedAccessException()
    {
        var orgA = Guid.NewGuid();
        var orgB = Guid.NewGuid();
        var entry = new JournalEntry { OrgId = orgA, IdempotencyKey = "SEC-BOLA-1", Currency = "USD" };

        Assert.Throws<UnauthorizedAccessException>(() =>
            entry.AddLine(new JournalLine { OrgId = orgB, AccountId = Guid.NewGuid(), Debit = 100m }));
    }

    [Fact]
    public void ReversalEntry_ProducesExactMirrorAndMarksOriginalReversed()
    {
        var orgId = Guid.NewGuid();
        var acc1 = Guid.NewGuid();
        var acc2 = Guid.NewGuid();

        var entry = new JournalEntry { OrgId = orgId, IdempotencyKey = "ORIG-1", Currency = "USD" };
        entry.AddLine(new JournalLine { OrgId = orgId, AccountId = acc1, Debit = 500m });
        entry.AddLine(new JournalLine { OrgId = orgId, AccountId = acc2, Credit = 500m });
        entry.EnsureBalanced();

        var reversal = entry.CreateReversal("REV-1", "Correction without mutating original");
        Assert.True(entry.IsReversed);
        Assert.Equal(reversal.Id, entry.ReversedById);
        Assert.Equal(500m, reversal.Lines.Single(l => l.AccountId == acc1).Credit);
        Assert.Equal(500m, reversal.Lines.Single(l => l.AccountId == acc2).Debit);
    }

    [Fact]
    public void BlindRating_RemainsHiddenUntilBothPartiesSubmitOrSevenDaysPass()
    {
        var svc = new P2PCommerceService();
        var now = DateTimeOffset.UtcNow;
        var buyerRating = new BlindRating { OrderId = Guid.NewGuid(), RaterRole = "BUYER", Score = 5, RevealAfter = now.AddDays(7) };
        var list = new List<BlindRating> { buyerRating };

        svc.RevealBlindRatingsIfEligible(list, now.AddDays(2));
        Assert.False(buyerRating.IsPublished);

        svc.RevealBlindRatingsIfEligible(list, now.AddDays(8));
        Assert.True(buyerRating.IsPublished);
    }
}
