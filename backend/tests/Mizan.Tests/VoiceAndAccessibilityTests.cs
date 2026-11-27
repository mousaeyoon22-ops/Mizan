using Mizan.Application.Accessibility;
using Mizan.Domain.Accessibility;
using Xunit;

namespace Mizan.Tests;

public sealed class VoiceAndAccessibilityTests
{
    [Fact]
    public void FinancialVoiceCommand_NeverAutoPosts_AndEnforcesHighValuePinGuard()
    {
        var svc = new VoiceCommandGovernanceService();
        var orgId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var profile = new UserAccessibilityProfile { UserId = userId, VoiceCommandsEnabled = true, VoiceHighValueThreshold = 500m };

        // High-value Arabic voice receipt (750 USD >= 500 USD threshold)
        var draft = svc.ProcessTranscript(orgId, userId, "VOICE-001", "سند قبض ٧٥٠ دولار من العميل الأمل", "ar", profile);
        Assert.Equal(VoiceIntent.RecordCashReceipt, draft.Intent);
        Assert.Equal(VoiceCommandState.DraftAwaitingConfirm, draft.State);
        Assert.Equal(750.0000m, draft.AmountValue);
        Assert.Equal("USD", draft.Currency);

        // Plain voice confirmation must be rejected for high-value amounts
        Assert.Throws<InvalidOperationException>(() =>
            svc.ConfirmDraft(orgId, userId, draft.Id, VoiceConfirmationMethod.VoiceExplicit, profile, Guid.NewGuid()));

        // PIN/Biometric confirmation succeeds
        var posted = svc.ConfirmDraft(orgId, userId, draft.Id, VoiceConfirmationMethod.PinOrBiometric, profile, Guid.NewGuid());
        Assert.Equal(VoiceCommandState.ConfirmedAndPosted, posted.State);
    }
}
