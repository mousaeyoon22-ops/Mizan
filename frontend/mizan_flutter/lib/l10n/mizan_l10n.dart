import 'package:flutter/material.dart';

class MizanLanguage {
  final String code;
  final String nativeName;
  final TextDirection direction;

  const MizanLanguage(this.code, this.nativeName, this.direction);
}

class MizanL10n {
  static const List<MizanLanguage> supported = [
    MizanLanguage('ar', 'العربية', TextDirection.rtl),
    MizanLanguage('en', 'English', TextDirection.ltr),
    MizanLanguage('fr', 'Français', TextDirection.ltr),
    MizanLanguage('tr', 'Türkçe', TextDirection.ltr),
    MizanLanguage('ur', 'اردو', TextDirection.rtl),
  ];

  static MizanLanguage byCode(String code) {
    return supported.firstWhere(
      (l) => l.code == code,
      orElse: () => supported.first,
    );
  }

  static bool isRtl(String code) => byCode(code).direction == TextDirection.rtl;

  static String tr(String lang, String key) {
    final map = _dict[key];
    if (map == null) return key;
    return map[lang] ?? map['en'] ?? map['ar'] ?? key;
  }

  static String localizedName(
    String lang,
    String fallback,
    Map<String, String> i18n,
  ) {
    final v = i18n[lang];
    if (v != null && v.trim().isNotEmpty) return v;
    if (lang != 'ar' && (i18n['en']?.trim().isNotEmpty ?? false)) {
      return i18n['en']!;
    }
    return fallback;
  }

  static const Map<String, Map<String, String>> _dict = {
    'app_title': {
      'ar': 'ميزان v3.3 — المنصة المحاسبية الشاملة',
      'en': 'Mizan v3.3 — Universal Accounting Suite',
      'fr': 'Mizan v3.3 — Suite Comptable Universelle',
      'tr': 'Mizan v3.3 — Evrensel Muhasebe Platformu',
      'ur': 'میزان v3.3 — جامع اکاؤنٹنگ پلیٹ فارم',
    },
    'nav_home': {
      'ar': 'الرئيسية',
      'en': 'Home',
      'fr': 'Accueil',
      'tr': 'Ana Sayfa',
      'ur': 'ہوم',
    },
    'nav_accounts': {
      'ar': 'الحسابات',
      'en': 'Accounts',
      'fr': 'Comptes',
      'tr': 'Hesaplar',
      'ur': 'کھاتے',
    },
    'nav_invoices': {
      'ar': 'الفواتير والدورات',
      'en': 'Invoices & Cycles',
      'fr': 'Factures & Cycles',
      'tr': 'Fatura & Döngü',
      'ur': 'بل اور سائیکلز',
    },
    'nav_vouchers': {
      'ar': 'السندات والقيود',
      'en': 'Vouchers & Ledger',
      'fr': 'Pièces & Journal',
      'tr': 'Fiş & Yevmiye',
      'ur': 'واؤچرز و کھاتہ',
    },
    'nav_inventory': {
      'ar': 'المخازن والأصناف',
      'en': 'Inventory',
      'fr': 'Stocks',
      'tr': 'Stok & Depo',
      'ur': 'اسٹاک و گودام',
    },
    'nav_network': {
      'ar': 'الشبكة و MGID',
      'en': 'Network & MGID',
      'fr': 'Réseau & MGID',
      'tr': 'Ağ & MGID',
      'ur': 'نیٹ ورک و MGID',
    },
    'nav_reports': {
      'ar': 'التقارير IFRS',
      'en': 'IFRS Reports',
      'fr': 'Rapports IFRS',
      'tr': 'IFRS Raporlar',
      'ur': 'IFRS رپورٹس',
    },
    'nav_more': {
      'ar': 'المزيد',
      'en': 'More',
      'fr': 'Plus',
      'tr': 'Diğer',
      'ur': 'مزید',
    },
    'login_subtitle': {
      'ar': 'نواة علائقية SQLite · 18 جدولاً · SHA-256 · 5 لغات · 6 دورات قطاعية',
      'en': 'Relational SQLite · 18 Tables · SHA-256 · 5 Languages · 6 Sector Cycles',
      'fr': 'SQLite Relationnel · 18 Tables · SHA-256 · 5 Langues · 6 Secteurs',
      'tr': 'İlişkisel SQLite · 18 Tablo · SHA-256 · 5 Dil · 6 Sektör',
      'ur': 'ریلیشنل SQLite · 18 جدول · SHA-256 · 5 زبانیں · 6 شعبے',
    },
    'login_btn': {
      'ar': 'دخول إلى المنصة',
      'en': 'Enter Workspace',
      'fr': 'Ouvrir l’espace',
      'tr': 'Çalışma Alanına Gir',
      'ur': 'پلیٹ فارم میں داخل ہوں',
    },
    'email': {
      'ar': 'البريد الإلكتروني',
      'en': 'Email',
      'fr': 'E-mail',
      'tr': 'E-posta',
      'ur': 'ای میل',
    },
    'entity': {
      'ar': 'المنشأة',
      'en': 'Entity',
      'fr': 'Entité',
      'tr': 'İşletme',
      'ur': 'ادارہ',
    },
    'branch': {
      'ar': 'الفرع',
      'en': 'Branch',
      'fr': 'Agence',
      'tr': 'Şube',
      'ur': 'برانچ',
    },
    'currency': {
      'ar': 'العملة',
      'en': 'Currency',
      'fr': 'Devise',
      'tr': 'Para Birimi',
      'ur': 'کرنسی',
    },
    'language': {
      'ar': 'اللغة العالمية',
      'en': 'Global Language',
      'fr': 'Langue Globale',
      'tr': 'Küresel Dil',
      'ur': 'عالمی زبان',
    },
    'cash_balance': {
      'ar': 'رصيد النقد والبنوك',
      'en': 'Cash & Banks',
      'fr': 'Trésorerie',
      'tr': 'Nakit & Banka',
      'ur': 'نقد اور بینک',
    },
    'receivables': {
      'ar': 'ذمم العملاء',
      'en': 'Receivables',
      'fr': 'Créances Clients',
      'tr': 'Alacaklar',
      'ur': 'وصولیاں',
    },
    'payables': {
      'ar': 'ذمم الموردين',
      'en': 'Payables',
      'fr': 'Dettes Fournisseurs',
      'tr': 'Borçlar',
      'ur': 'ادائیگیاں',
    },
    'net_profit': {
      'ar': 'صافي الربح (IAS 1)',
      'en': 'Net Profit (IAS 1)',
      'fr': 'Résultat Net (IAS 1)',
      'tr': 'Net Kâr (IAS 1)',
      'ur': 'خالص منافع (IAS 1)',
    },
    'trust_score': {
      'ar': 'مؤشر الثقة الدفتري',
      'en': 'Ledger Trust Score',
      'fr': 'Score de Confiance',
      'tr': 'Defter Güven Puanı',
      'ur': 'لیجر ٹرسٹ اسکور',
    },
    'zero_start': {
      'ar': 'بدء منشأة جديدة (تصفير كامل 0.00)',
      'en': 'Start Fresh Entity (True 0.00 Reset)',
      'fr': 'Nouvelle Entité (Zéro 0.00)',
      'tr': 'Yeni İşletme Başlat (Tam 0.00)',
      'ur': 'نیا ادارہ شروع کریں (مکمل 0.00)',
    },
    'fx_center': {
      'ar': 'العملات وإعادة التقييم IAS 21',
      'en': 'FX & IAS 21 Revaluation',
      'fr': 'Devises & Réévaluation IAS 21',
      'tr': 'Döviz & IAS 21 Değerleme',
      'ur': 'کرنسیاں اور IAS 21',
    },
    'custom_doors': {
      'ar': 'الأبواب المخصصة وحزم الدول',
      'en': 'Custom Doors & Country Packs',
      'fr': 'Modules & Packs Pays',
      'tr': 'Özel Modüller & Ülke Paketleri',
      'ur': 'کسٹم ماڈیولز اور ملکی پیکجز',
    },
    'export_pdf': {
      'ar': 'تصدير PDF / واتساب',
      'en': 'Export PDF / WhatsApp',
      'fr': 'Exporter PDF / WhatsApp',
      'tr': 'PDF / WhatsApp Paylaş',
      'ur': 'PDF / واٹس ایپ شیئر',
    },
    'thermal_print': {
      'ar': 'طباعة حرارية 80مم',
      'en': '80mm Thermal Print',
      'fr': 'Impression 80mm',
      'tr': '80mm Termal Yazdır',
      'ur': '80mm تھرمل پرنٹ',
    },
    'import_csv': {
      'ar': 'استيراد Excel/CSV تجريبي',
      'en': 'Excel/CSV Dry-Run Import',
      'fr': 'Import Excel/CSV Test',
      'tr': 'Excel/CSV Deneme İçe Aktar',
      'ur': 'Excel/CSV آزمائشی امپورٹ',
    },
    'export_csv': {
      'ar': 'تصدير Excel/CSV',
      'en': 'Export Excel/CSV',
      'fr': 'Exporter Excel/CSV',
      'tr': 'Excel/CSV Dışa Aktar',
      'ur': 'Excel/CSV ایکسپورٹ',
    },
    'reverse_entry': {
      'ar': 'قيد عكسي',
      'en': 'Reverse Entry',
      'fr': 'Contre-passation',
      'tr': 'Ters Kayıt',
      'ur': 'ریورس انٹری',
    },
    'save': {
      'ar': 'حفظ',
      'en': 'Save',
      'fr': 'Enregistrer',
      'tr': 'Kaydet',
      'ur': 'محفوظ کریں',
    },
    'cancel': {
      'ar': 'إلغاء',
      'en': 'Cancel',
      'fr': 'Annuler',
      'tr': 'İptal',
      'ur': 'منسوخ',
    },
    'balanced': {
      'ar': 'متوازن 100%',
      'en': '100% Balanced',
      'fr': 'Équilibré 100%',
      'tr': '%100 Dengeli',
      'ur': '100% متوازن',
    },
    'dark_mode': {
      'ar': 'الوضع الليلي',
      'en': 'Dark Mode',
      'fr': 'Mode Sombre',
      'tr': 'Karanlık Mod',
      'ur': 'ڈارک موڈ',
    },
    'sqlite_active': {
      'ar': 'محرك SQLite العلائقي (18 جدولاً): نشط ومتصل',
      'en': 'Relational SQLite Engine (18 tables): Active',
      'fr': 'SQLite Relationnel (18 tables) : Actif',
      'tr': 'İlişkisel SQLite (18 tablo): Aktif',
      'ur': 'ریلیشنل SQLite (18 جدول): فعال',
    },
  };
}
