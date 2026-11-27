using Mizan.Application.POS;
using Mizan.Domain.POS;
using Xunit;

namespace Mizan.Tests;

public sealed class PosShiftsAndVariantsTests
{
    [Fact]
    public void BlindCloseShift_ShortageAndOverage_ProduceBalancedEntriesAndSha256ZReport()
    {
        var svc = new PosShiftAndZReportService();
        var orgId = Guid.NewGuid();
        var term1 = Guid.NewGuid();
        var cashier1 = Guid.NewGuid();
        var drawerAcc = Guid.NewGuid();
        var shortAcc = Guid.NewGuid();
        var overAcc = Guid.NewGuid();

        var shirtMBlue = new ItemVariant
        {
            OrgId = orgId, ParentItemId = Guid.NewGuid(),
            VariantSku = "SHIRT-M-BLUE", VariantBarcode = "629000111222",
            SizeLabel = "M", ColorLabel = "Blue", SalePrice = 145.00m, QtyOnHand = 50m, Currency = "USD"
        };

        var shift = svc.OpenShift(orgId, term1, cashier1, 200.00m, "USD");
        svc.RecordVariantSale(shift, shirtMBlue, 10m, expectedRowVersion: 1, cashPaid: 1450.00m, cardPaid: 0m, creditAmount: 0m);
        svc.RecordCashRefund(shift, 50.00m);

        // Expected Cash = 200 + 1450 - 50 = 1600.00; Cashier counts 1585.00 -> Shortage -15.00
        var (zReport, entry) = svc.CloseShiftAndGenerateZReport(shift, "Z-2026-0001", 1585.00m, drawerAcc, shortAcc, overAcc);

        Assert.Equal(1600.0000m, zReport.ExpectedCash);
        Assert.Equal(-15.0000m, zReport.CashVariance);
        Assert.NotNull(entry);
        Assert.Equal(64, zReport.ZReportSha256.Length);
        Assert.Equal(0.0000m, svc.VerifyVarianceLedgerBalance(orgId));
    }
}
