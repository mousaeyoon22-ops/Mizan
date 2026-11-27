using Mizan.Application.Features;
using Mizan.Application.FX;
using Mizan.Application.Reports;
using Mizan.Application.Translation;
using Mizan.Domain.Features;
using Xunit;

namespace Mizan.Tests;

public sealed class FeatureGovernanceAndFxTests
{
    [Fact]
    public void Phase1Registry_ContainsAll25Features_WithPhase2And3LockedOff()
    {
        var gov = new FeatureGovernanceService(MizanFeatureKeys.Phase1DefaultRegistry());
        var orgId = Guid.NewGuid();
        var matrix = gov.GetEffectiveMatrix(orgId);

        Assert.Equal(25, matrix.Count);
        Assert.True(gov.IsEnabled(orgId, MizanFeatureKeys.CoreDoubleEntryLedger));
        Assert.True(gov.IsEnabled(orgId, MizanFeatureKeys.AccessibilityInclusiveMode));
        Assert.True(gov.IsEnabled(orgId, MizanFeatureKeys.WorkspaceExperienceModes));
        Assert.False(gov.IsEnabled(orgId, MizanFeatureKeys.PosMultiCashierTouch));
        Assert.False(gov.IsEnabled(orgId, MizanFeatureKeys.VoiceCommandOperations));
        Assert.False(gov.IsEnabled(orgId, MizanFeatureKeys.PspPassThroughPreAuth));
        Assert.False(gov.IsEnabled(orgId, MizanFeatureKeys.InternalWalletCustody));

        Assert.Throws<InvalidOperationException>(() =>
            gov.SetOrganizationPreference(orgId, MizanFeatureKeys.PspPassThroughPreAuth, true));
    }

    [Fact]
    public void A4CleanReportBuilder_StripsEmptyRowsAndPlaceholdersDynamically()
    {
        var builder = new A4CleanReportBuilder();
        var model = builder.BuildCleanModel(
            "محطة مياه صحة", new DateOnly(2026, 11, 24), "USD",
            rawSales: new[]
            {
                new DailySalesRow("متجر الأمل", "عبوة 20 لتر", 50m, 2m, 100m, "CASH"),
                new DailySalesRow("", "", 0m, 0m, 0m, ""),
                new DailySalesRow("TBD", "---", 0m, 0m, 0m, "")
            },
            rawExpenses: new[]
            {
                new DailyExpenseRow("وقود", "ديزل سيارة التوزيع", 25m),
                new DailyExpenseRow("فارغ", "", 0m)
            },
            rawMeters: new[]
            {
                new MeterReadingRow("عداد التعبئة الرئيسي", 1200m, 1250m),
                new MeterReadingRow("---", 0m, 0m)
            },
            rawBalances: new[]
            {
                new CustomerBalanceRow("متجر الأمل", 300m, 100m, 50m),
                new CustomerBalanceRow("عميل صفري", 0m, 0m, 0m)
            },
            trialBalanceVariance: 0m,
            hideEmptyRows: true);

        Assert.Single(model.SalesRows);
        Assert.Single(model.ExpenseRows);
        Assert.Single(model.MeterReadings);
        Assert.Single(model.CustomerBalances);
        Assert.Equal(75m, model.NetCashFlow);

        var html = builder.RenderA4Html(model, isArabic: true);
        Assert.Contains("متجر الأمل", html);
        Assert.DoesNotContain("TBD", html);
        Assert.DoesNotContain("عميل صفري", html);
    }

    [Fact]
    public void DirectCurrencyExchangeVoucher_PostsBalancedSpreadExpense_ZeroVariance()
    {
        var fx = new Ias21FxAccountingEngine();
        var orgId = Guid.NewGuid();
        var res = fx.ExecuteDirectCurrencyExchange(
            orgId, "EXCH-UNIT-1", Guid.NewGuid(), "SAR",
            Guid.NewGuid(), "USD", 1000m, 3.75m,
            Guid.NewGuid(), "SAR", 3720m, 1.00m,
            Guid.NewGuid(), Guid.NewGuid());

        Assert.Equal(-30.0000m, res.FxDiffBaseAmount);
        Assert.Equal(0.0000m, fx.VerifyBaseTrialBalanceVariance(orgId));
    }

    [Fact]
    public async Task InstantTranslation_BlockedByPolicyInPhase1()
    {
        var gov = new FeatureGovernanceService(MizanFeatureKeys.Phase1DefaultRegistry());
        var svc = new InstantTranslationService(new DisabledTranslationAdapter(), (o, k) => gov.IsEnabled(o, k));

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            svc.TranslateFieldAsync(Guid.NewGuid(), "عبوة مياه نقية", "ar", "en"));
    }
}
