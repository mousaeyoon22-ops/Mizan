import 'package:flutter_test/flutter_test.dart';
import 'package:mizan_app/db/mizan_database.dart';
import 'package:mizan_app/engine/ifrs_engine.dart';
import 'package:mizan_app/l10n/mizan_l10n.dart';
import 'package:mizan_app/models/mizan_models.dart';

void main() {
  test('SHA-256 and MGID are deterministic', () {
    final h1 = MizanSha256.digestHex('mizan-v3.3');
    final h2 = MizanSha256.digestHex('mizan-v3.3');
    expect(h1, equals(h2));
    expect(h1.length, equals(64));
    expect(MizanSha256.generateMgid('WTR', 'Seha Water', 'Bottle').startsWith('MGID-WTR-'), isTrue);
  });

  test('UUID v7 generates unique ids', () {
    expect(MizanUuidV7.next(), isNot(equals(MizanUuidV7.next())));
  });

  test('IFRS Engine computes balanced trial balance and IAS 1 profit', () {
    final accounts = [
      MizanAccount(id: 'c1', code: '1101', name: 'Cash', type: AccountType.cashbox),
      MizanAccount(id: 'r1', code: '4101', name: 'Sales', type: AccountType.revenue),
    ];
    final journals = [
      JournalHeader(
        id: 'j1', refNo: 'JV-1', entryDate: DateTime(2026, 11, 28),
        branchName: 'Main', description: 'Sale', category: 'SALE', sha256Hash: 'abc',
        lines: [
          JournalLine(id: 'l1', headerId: 'j1', accountId: 'c1', accountName: 'Cash', debit: 500, credit: 0),
          JournalLine(id: 'l2', headerId: 'j1', accountId: 'r1', accountName: 'Sales', debit: 0, credit: 500),
        ],
      ),
    ];
    final snap = IfrsEngine.compute(accounts: accounts, journals: journals, asOfDate: DateTime(2026, 12, 1));
    expect(snap.isBalanced, isTrue);
    expect(snap.netProfit, equals(500.0));
  });

  test('Smart remittance parser and 5-language l10n work', () {
    final rem = IfrsEngine.parseRemittanceText('حوالة رقم 7788 بمبلغ 250 ريال سعودي من النور');
    expect(rem.amount, equals(250.0));
    expect(rem.currency, equals('SAR'));
    expect(MizanL10n.supported.length, equals(5));
  });
}
