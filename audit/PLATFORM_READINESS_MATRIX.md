# مصفوفة جاهزية المنصات والنشر — ميزان (Mizan Production Ready v2.2)

| المكوّن / المنصة | حالة الجاهزية الحالية | ما تم التحقق منه فعلياً الآن | ما يتطلب تشغيله على خادمك المحلي / CI |
| :--- | :--- | :--- | :--- |
| **الخادم الخلفي (.NET 8 — 12 Controller + 8 محركات + Hangfire)** | **مطابق 100% للمخطط (`v2.2`) — بانتظار `dotnet test`** | `PAR-01/02`: 15/15 كيان و15/15 Enum مطابقة تماماً لـ PostgreSQL؛ صفر استدعاءات صورية؛ تدوير Refresh Token وجدولة Hangfire. | تشغيل `dotnet test backend/Mizan.sln --configuration Release`. |
| **قاعدة البيانات (PostgreSQL 16 — 10 ترحيلات `001`–`010`)** | **مشددة بالكامل (`NULLIF` + `FORCE RLS` + `mizan_runtime`)** | `PAR-03`: ترقية جميع السياسات الـ 22 بـ `NULLIF` و`WITH CHECK`؛ فهارس الذروة (`81.6x`). | تشغيل `bash scripts/deploy_local_city_pilot.sh` و`test_pg_rls_and_invariants.sql`. |
| **تطبيق Flutter (8 ترحيلات SQLite + Auth API + POS + صوت + 5 أوضاع)** | **موصول بالكامل بـ API (`v2.2`) — بانتظار بناء APK** | `MizanApiClient` يدعم `login/refresh/features/meters`، `LoginOnboardingScreen` موصول بخيار أوفلاين، و8 ترحيلات SQLite (16 جدولاً). | تشغيل `flutter pub get && flutter analyze && flutter test && flutter build apk --release`. |
| **الرفيق الميداني أوفلاين (`local_pilot_web/mizan_field_companion.html`)** | **جاهز للاستخدام الفوري من اليوم الأول** | يعمل مباشرة على متصفح الهاتف دون خادم (مبيعات، عدادات، عهدة، طباعة A4 نظيفة، JSON). | فتح الملف على هاتف الموزع/التاجر للبدء الفوري. |
| **التشغيل والنسخ الاحتياطي وCI/CD** | **مُصححة ومتكاملة (`mizan_admin`)** | إصلاح `backup/restore.sh` ودمج اختبار RLS الحي في `.github/workflows/ci.yml`. | تشغيل أول دورة CI واختبار `backup_postgres.sh` / `restore_postgres.sh`. |
