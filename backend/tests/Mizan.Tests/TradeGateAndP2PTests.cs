using Mizan.Application.Services;
using Mizan.Domain.Entities;
using Xunit;

namespace Mizan.Tests;

public sealed class TradeGateAndP2PTests
{
    [Fact]
    public void SeparateDecisions_PairingAloneCannotSendDocumentWithoutGateApproval()
    {
        var svc = new TradeGateService();
        var orgA = Guid.NewGuid();
        var orgB = Guid.NewGuid();
        var pairing = new Pairing { OrgAId = orgA, OrgBId = orgB, Status = PairingStatus.Active };
        var unapprovedGate = new TradeGate { PairingId = pairing.Id, SenderOrgId = orgA, ReceiverOrgId = orgB, ApprovedBySender = true, ApprovedByReceiver = false };

        Assert.Throws<InvalidOperationException>(() =>
            svc.SendDocument(pairing, unapprovedGate, orgA, "DOC-1", "INVOICE", "{}"));
    }

    [Fact]
    public void PerishableDispute_BlocksGalleryUpload_AndEnforces30MinWindow()
    {
        var svc = new P2PCommerceService();
        var deliveredAt = DateTimeOffset.UtcNow.AddMinutes(-20);
        var order = new P2POrder { DeliveredAt = deliveredAt };
        var veg = new InventoryItem { IsPerishable = true };

        Assert.False(svc.CanOpenDispute(order, veg, DateTimeOffset.UtcNow, isLiveInAppCapture: false));
        Assert.True(svc.CanOpenDispute(order, veg, DateTimeOffset.UtcNow, isLiveInAppCapture: true));
        Assert.False(svc.CanOpenDispute(order, veg, deliveredAt.AddMinutes(31), isLiveInAppCapture: true));
    }
}
