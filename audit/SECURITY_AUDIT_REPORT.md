# تقرير التدقيق الأمني النهائي — ميزان (Mizan Production Ready v2.2)

## 1. الإغلاقات الأمنية الحرجة المضافة في `v2.2`
1. **DEF-401 [P0 — مغلق]:** استبدال التحويل المباشر `current_setting(...)::UUID` في **جميع السياسات الـ 22** بدالتَي `mizan_current_org_id()` و`mizan_current_user_id()` باستخدام `NULLIF(..., '')::UUID` مع إضافة بند `WITH CHECK` صريح لكل سياسة في الترحيل `010_rls_nullif_uuid_safety.sql` (منع تعطل `22P02` ومنع إدخال صفوف لمنشأة أخرى).
2. **DEF-404 [P0 — مغلق]:** إضافة `POST /api/v1/auth/refresh` بتدوير ذري لرموز التحديث وكشف إعادة الاستخدام (Reuse Detection يبطل جميع جلسات المستخدم تلقائياً عند اكتشاف سرقة/إعادة استخدام رمز ملغى)، وإلغاء قراءة ترويسة `[FromHeader] X-Org-Id` المباشرة في `FeaturePreferencesController` و`FxAndTranslationController` وربطها حصراً بـ `_tenant.ActiveOrgId` وقصر تعديل الميزات على دور `OWNER`.
3. **DEF-406 [P1 — مغلق]:** تصحيح مستخدم قاعدة البيانات في `backup_postgres.sh` و`restore_postgres.sh` إلى `mizan_admin` وإضافة اختبار RLS حيّ (`database/tests/test_pg_rls_and_invariants.sql`) إلى `.github/workflows/ci.yml`.
4. **ملخص الحماية الشاملة عبر `v1.0`–`v2.2`:** PBKDF2-SHA512 (100k)، JWT HS256 (≥256-bit)، `mizan_runtime` (`NOSUPERUSER NOBYPASSRLS`) + `FORCE RLS` على 22 جدولاً، منع BOLA في REST وSignalR، منع تصعيد RBAC في أوضاع العرض، بوابة PIN للصوت عالي القيمة، مشغّلات عدم التعديل على القيود وZ-Report وسجل الصوت والتدقيق، SQLCipher محلياً، وتشفير النسخ بـ AES-256-CBC.

## 2. الاختبارات المتبقية على البيئة الحية
* تشغيل `database/tests/test_pg_rls_and_invariants.sql` على خادم PostgreSQL 16 حي (مُدمج تلقائياً في CI).
* استبدال الشهادة المحلية بـ Let's Encrypt عند النشر على الإنترنت، وإجراء اختبار اختراق خارجي مستقل قبل التوسع للجمهور العام.
