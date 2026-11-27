import 'package:flutter/material.dart';

/// Lightweight, zero-codegen bilingual localization (Arabic RTL + English LTR)
/// extensible to any global language pack.
class MizanStrings {
  final Locale locale;
  const MizanStrings(this.locale);

  bool get isRtl => locale.languageCode == 'ar';

  static const Map<String, Map<String, String>> _dict = {
    'ar': {
      'app_title': 'ميزان — سجل العمليات المحاسبي',
      'dashboard': 'لوحة التحكم',
      'qr_cart': 'مسح QR والسلة الحية',
      'trade_gates': 'الأبواب التجارية',
      'nearby': 'المتاجر القريبة',
      'offline_pending': 'عمليات بانتظار المزامنة',
      'sync_now': 'مزامنة الآن',
      'synced_ok': 'جميع البيانات متزامنة',
      'scan_store_qr': 'امسح كود QR للمتجر لفتح الكتالوج',
      'live_cart_active': 'السلة الحية متصلة مع كاشير المتجر',
      'payment_mode': 'وسيلة الدفع وإثبات الجدية',
      'pay_preauth': 'بوابة تمرير (تفويض مسبق آمن)',
      'pay_cash': 'نقداً عند المعاينة (كاش)',
      'pay_credit': 'آجل (ضمن السقف المعتمد)',
      'pay_partial': 'نصف آجل (دفعة + ذمة)',
      'submit_order': 'إرسال الطلب وحجز الأصناف',
      'confirm_release': 'تأكيد المعاينة والإفراج عن الدفع',
      'open_dispute': 'اعتراض / تلف (كاميرا حية فقط)',
      'gallery_blocked': 'ممنوع رفع صور من الاستوديو — التصوير الحي إلزامي لمنع التزوير',
      'perishable_window': 'نافذة الاعتراض للسلع السريعة: 30 دقيقة من الاستلام',
      'blind_rating_title': 'التقييم الأعمى المتبادل',
      'blind_rating_hint': 'لا يظهر تقييمك للطرف الآخر إلا بعد تقييمه لك أو مرور 7 أيام.',
      'chat_locked': 'الدردشة مقفلة كأرشيف قانوني للقراءة فقط بعد إغلاق المعاملة.',
      'gate_decisions': 'القرارات الثلاثة: اقتران ← موافقة الباب ← ترحيل محاسبي مستقل',
    },
    'en': {
      'app_title': 'Mizan — Accounting Operations Ledger',
      'dashboard': 'Dashboard',
      'qr_cart': 'QR Live Cart',
      'trade_gates': 'Trade Gates',
      'nearby': 'Nearby Stores',
      'offline_pending': 'Pending Offline Sync',
      'sync_now': 'Sync Now',
      'synced_ok': 'All records synced',
      'scan_store_qr': 'Scan Store QR to load live catalog',
      'live_cart_active': 'Live Cart synced with Store Cashier',
      'payment_mode': 'Payment Mode & Commitment',
      'pay_preauth': 'Pass-Through PSP (Pre-Authorization)',
      'pay_cash': 'Cash on Inspection',
      'pay_credit': 'Credit (Pre-Approved Limit)',
      'pay_partial': 'Partial Credit (Split)',
      'submit_order': 'Submit Order & Reserve Stock',
      'confirm_release': 'Confirm Inspection & Release Funds',
      'open_dispute': 'Open Dispute (Live Camera Only)',
      'gallery_blocked': 'Gallery uploads disabled — Live in-app camera capture mandatory.',
      'perishable_window': 'Perishable dispute window: 30 minutes from delivery.',
      'blind_rating_title': 'Double-Blind Mutual Rating',
      'blind_rating_hint': 'Ratings remain hidden until both sides submit or 7 days pass.',
      'chat_locked': 'Transaction chat locked as read-only legal archive.',
      'gate_decisions': '3 Decisions: Pairing -> Bilateral Gate Approval -> Independent Posting',
    },
  };

  String t(String key) => _dict[locale.languageCode]?[key] ?? _dict['en']?[key] ?? key;
}
