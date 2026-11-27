using Mizan.Application.Workspace;
using Mizan.Domain.Workspace;
using Xunit;

namespace Mizan.Tests;

public sealed class WorkspaceExperienceModesTests
{
    [Fact]
    public void CashierRequestingProfessionalMode_IsClampedByRbacCeiling_AndHidesSensitiveFields()
    {
        var svc = new WorkspaceModeResolverService();
        var profile = svc.Resolve("CASHIER", WorkspaceExperienceMode.Professional);

        Assert.True(profile.WasClampedByRoleOrPolicy);
        Assert.Equal(WorkspaceExperienceMode.Standard, profile.EffectiveMode);
        Assert.DoesNotContain("gross_profit", profile.VisibleWidgets);
        Assert.DoesNotContain("journal_debit_credit", profile.VisibleWidgets);
    }

    [Fact]
    public void AccountantInProfessionalMode_ReceivesFullCoaDebitCreditFifoAndSha256Columns()
    {
        var svc = new WorkspaceModeResolverService();
        var profile = svc.Resolve("ACCOUNTANT", WorkspaceExperienceMode.Professional);

        Assert.False(profile.WasClampedByRoleOrPolicy);
        Assert.Equal(WorkspaceExperienceMode.Professional, profile.EffectiveMode);
        Assert.Equal(TerminologyStyle.StrictAccounting, profile.Terminology);
        Assert.Equal(UiDensity.Compact, profile.Density);
        Assert.Contains("coa_code", profile.VisibleTableColumns);
        Assert.Contains("base_debit", profile.VisibleTableColumns);
        Assert.Contains("audit_sha256_hash", profile.VisibleTableColumns);
    }
}
