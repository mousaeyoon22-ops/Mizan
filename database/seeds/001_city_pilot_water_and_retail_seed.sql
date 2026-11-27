-- ============================================================================
-- MIZAN (ميزان) — City Pilot Reference Seed (Safe Idempotent Template)
-- Sector: Water Purification & Distribution Station + Connected Retail Shops
-- ============================================================================
-- Run AFTER Migrations 001 -> 009 using psql against staging/pilot DB.
-- Replace password hashes via POST /api/v1/auth/register in live environments.

INSERT INTO users (id, uid_code, email, phone, password_hash, kyc_level, preferred_lang, base_currency)
VALUES
('11111111-1111-1111-1111-111111111101', 'USR-100001', 'owner@seha-pilot.local', '+967700000001', 'BOOTSTRAP_RESET_REQUIRED', 2, 'ar', 'YER'),
('11111111-1111-1111-1111-111111111102', 'USR-100002', 'driver@seha-pilot.local', '+967700000002', 'BOOTSTRAP_RESET_REQUIRED', 1, 'ar', 'YER'),
('11111111-1111-1111-1111-111111111103', 'USR-100003', 'shop@alamal-pilot.local', '+967700000003', 'BOOTSTRAP_RESET_REQUIRED', 2, 'ar', 'YER')
ON CONFLICT (uid_code) DO NOTHING;

INSERT INTO organizations (id, owner_user_id, uid_code, trade_name, sector, visibility_mode, base_currency, inventory_method)
VALUES
('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101', 'ORG-SEHA-01', 'محطة مياه صحة (التشغيل الميداني)', 'water_distribution', 'QR_ONLY', 'YER', 'FIFO'),
('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111103', 'ORG-SHOP-01', 'بقالة الأمل للتجزئة', 'retail', 'QR_ONLY', 'YER', 'FIFO')
ON CONFLICT (uid_code) DO NOTHING;

INSERT INTO organization_members (org_id, user_id, role)
VALUES
('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101', 'OWNER'),
('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111102', 'DRIVER'),
('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111103', 'OWNER')
ON CONFLICT (org_id, user_id) DO NOTHING;

-- Standard Bilingual Chart of Accounts for Water Station Org
INSERT INTO accounts (org_id, code, name, account_type, currency)
VALUES
('22222222-2222-2222-2222-222222222201', '1110', 'الصندوق الرئيسي / Main Cash Box', 'ASSET', 'YER'),
('22222222-2222-2222-2222-222222222201', '1120', 'الذمم المدينة (العملاء) / Accounts Receivable', 'ASSET', 'YER'),
('22222222-2222-2222-2222-222222222201', '1130', 'المخزون (العبوات والمستلزمات) / Inventory', 'ASSET', 'YER'),
('22222222-2222-2222-2222-222222222201', '2110', 'الذمم الدائنة (الموردون) / Accounts Payable', 'LIABILITY', 'YER'),
('22222222-2222-2222-2222-222222222201', '2130', 'دفعات العملاء المقدمة (IFRS 15) / Customer Advances', 'LIABILITY', 'YER'),
('22222222-2222-2222-2222-222222222201', '4110', 'إيراد مبيعات المياه / Water Sales Revenue', 'REVENUE', 'YER'),
('22222222-2222-2222-2222-222222222201', '4120', 'أرباح فروقات العملة والمصارفة / FX Gain', 'REVENUE', 'YER'),
('22222222-2222-2222-2222-222222222201', '5110', 'تكلفة المبيعات (IAS 2) / Cost of Goods Sold', 'EXPENSE', 'YER'),
('22222222-2222-2222-2222-222222222201', '5210', 'مصروفات الوقود والتشغيل / Fuel & Operating Expenses', 'EXPENSE', 'YER'),
('22222222-2222-2222-2222-222222222201', '5220', 'خسائر فروقات الصرف والمصارفة / FX Loss', 'EXPENSE', 'YER')
ON CONFLICT (org_id, code) DO NOTHING;
