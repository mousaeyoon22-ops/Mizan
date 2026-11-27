using Mizan.Domain.Accessibility;
using Mizan.Domain.Entities;
using Mizan.Domain.POS;
using Mizan.Infrastructure.Persistence;
using Xunit;

namespace Mizan.Tests;

public sealed class EfCoreSchemaEnumParityTests
{
    [Fact]
    public void ScreamingSnakeEnumConverter_MatchesPostgreSqlCheckConstraintsExactly()
    {
        Assert.Equal("ASSET", ScreamingSnakeEnumConverter<AccountType>.ToPgString(AccountType.Asset));
        Assert.Equal("GATEWAY_PREAUTH", ScreamingSnakeEnumConverter<PaymentMode>.ToPgString(PaymentMode.GatewayPreAuth));
        Assert.Equal("PREAUTHORIZED", ScreamingSnakeEnumConverter<PaymentStatus>.ToPgString(PaymentStatus.PreAuthorized));
        Assert.Equal("LIVE_CART", ScreamingSnakeEnumConverter<P2POrderState>.ToPgString(P2POrderState.LiveCart));
        Assert.Equal("LOADING_CUSTODY", ScreamingSnakeEnumConverter<GateType>.ToPgString(GateType.LoadingCustody));
        Assert.Equal("DRAFT_AWAITING_CONFIRM", ScreamingSnakeEnumConverter<VoiceCommandState>.ToPgString(VoiceCommandState.DraftAwaitingConfirm));
        Assert.Equal("EXECUTED_READONLY", ScreamingSnakeEnumConverter<VoiceCommandState>.ToPgString(VoiceCommandState.ExecutedReadOnly));
        Assert.Equal("BLIND_SCREEN_READER", ScreamingSnakeEnumConverter<AccessibilityPreset>.ToPgString(AccessibilityPreset.BlindScreenReader));
        Assert.Equal("OPEN", ScreamingSnakeEnumConverter<ShiftStatus>.ToPgString(ShiftStatus.Open));

        // Round-trip verification
        Assert.Equal(PaymentMode.GatewayPreAuth, ScreamingSnakeEnumConverter<PaymentMode>.FromPgString("GATEWAY_PREAUTH"));
        Assert.Equal(VoiceCommandState.DraftAwaitingConfirm, ScreamingSnakeEnumConverter<VoiceCommandState>.FromPgString("DRAFT_AWAITING_CONFIRM"));
    }
}
