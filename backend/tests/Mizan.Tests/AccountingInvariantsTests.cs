using Mizan.Application.Services;
using Mizan.Domain.Entities;
using Xunit;

namespace Mizan.Tests;

public sealed class AccountingInvariantsTests
{
    [Fact]
    public void WedgeCycle_WaterDistributor_ZeroVariance_IFRS15_And_IAS2_FIFO()
    {
        var engine = new DoubleEntryAccountingEngine();
        var orgId = Guid.NewGuid();
        var supplierId = Guid.NewGuid();
        var customerId = Guid.NewGuid();

        var cashAcc = Guid.NewGuid();
        var arAcc = Guid.NewGuid();
        var invAcc = Guid.NewGuid();
        var apAcc = Guid.NewGuid();
        var advAcc = Guid.NewGuid();
        var revAcc = Guid.NewGuid();
        var cogsAcc = Guid.NewGuid();

        var waterBottle = new InventoryItem { OrgId = orgId, Sku = "WTR-20L", Name = "20L Purified Water", SalePrice = 10.00m, Currency = "USD" };

        // 1. Purchase Batch 1: 100 units @ $4.00
        engine.RecordInventoryPurchase(orgId, "PUR-001", Guid.NewGuid(), waterBottle, 100m, 4.00m, invAcc, apAcc, supplierId, "USD");
        // 2. Purchase Batch 2: 100 units @ $5.00
        engine.RecordInventoryPurchase(orgId, "PUR-002", Guid.NewGuid(), waterBottle, 100m, 5.00m, invAcc, apAcc, supplierId, "USD");

        // 3. Customer pays $500 advance BEFORE delivery (IFRS 15 -> Liability, NOT Revenue)
        engine.RecordCustomerAdvancePayment(orgId, "ADV-001", Guid.NewGuid(), 500.00m, cashAcc, advAcc, customerId, "USD");
        Assert.Equal(0m, engine.CalculateAccountBalance(orgId, revAcc));

        // 4. Deliver 120 units @ $10.00 (IFRS 15 Revenue = $1200; Advance applied = $500; AR = $700; IAS 2 FIFO COGS = 100*4 + 20*5 = $500)
        var (_, rev, cogs) = engine.RecordDeliveryAndRecognizeRevenue(
            orgId, "DEL-001", Guid.NewGuid(), waterBottle, 120m, 10.00m, 500.00m,
            InventoryValuationMethod.Fifo, arAcc, advAcc, revAcc, cogsAcc, invAcc, customerId, "USD");

        Assert.Equal(1200.00m, rev);
        Assert.Equal(500.00m, cogs);
        Assert.Equal(80m, waterBottle.QtyOnHand);
        Assert.Equal(700.00m, engine.CalculateAccountBalance(orgId, arAcc));
        Assert.Equal(0.0000m, engine.VerifyTrialBalanceVariance(orgId));
    }

    [Fact]
    public void DuplicateIdempotencyKey_DoesNotDoublePost()
    {
        var engine = new DoubleEntryAccountingEngine();
        var orgId = Guid.NewGuid();
        var cashAcc = Guid.NewGuid();
        var advAcc = Guid.NewGuid();

        var first = engine.RecordCustomerAdvancePayment(orgId, "DUP-KEY-99", Guid.NewGuid(), 250m, cashAcc, advAcc, null, "USD");
        var second = engine.RecordCustomerAdvancePayment(orgId, "DUP-KEY-99", Guid.NewGuid(), 250m, cashAcc, advAcc, null, "USD");

        Assert.Equal(first.Id, second.Id);
        Assert.Single(engine.Ledger);
        Assert.Equal(250.00m, engine.CalculateAccountBalance(orgId, cashAcc));
    }
}
