# تحسينات واجهة الخريطة - WawApp Admin

## المتطلبات (من المستخدم)

### 1. توسيع مساحة الخريطة
- ✅ جعل الخريطة تحتل معظم الشاشة
- ✅ تصغير دليل الخريطة (Legend) أو تحويله لأيقونات قابلة للطي
- ✅ تقليل حجم البانل السفلي

### 2. إضافة بحث ذكي محسّن
- ✅ البحث في الأماكن المحفوظة في قاعدة البيانات
- ✅ البحث في نقاط الاهتمام (POIs) - المطاعم، الفنادق، الخ
- ✅ البحث في المقاطعات
- ✅ الانتقال التلقائي للموقع عند الاختيار
- ✅ نتائج فورية أثناء الكتابة

---

## التغييرات المطلوبة

### التغيير 1: تحويل دليل الخريطة إلى أيقونات قابلة للطي

**الملف:** `map_location_picker.dart`

**الحالة الحالية:**
- دليل كبير يحتل مساحة ثابتة في الزاوية اليسرى السفلى
- يعرض جميع المقاطعات ونقاط الاهتمام دائمًا
- يأخذ ~160px عرض × ~200px ارتفاع

**الحالة المطلوبة:**
- زر أيقونة صغير فقط (🗺️ أو info icon)
- عند الضغط يتوسع ليظهر الدليل الكامل
- يغلق بسهولة بزر X
- **مثل ما فعلناه في LiveMap!**

**الكود:**

```dart
// إضافة state variable
bool _legendExpanded = false;

// استبدال _buildLegend() بـ _buildCollapsibleLegend()
Widget _buildCollapsibleLegend() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // الحالة المطوية - فقط أيقونة
      if (!_legendExpanded)
        Material(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          child: IconButton(
            icon: const Icon(Icons.map, size: 22, color: _kGreen),
            tooltip: 'إظهار دليل الخريطة',
            onPressed: () => setState(() => _legendExpanded = true),
          ),
        ),

      // الحالة الموسعة - دليل كامل
      if (_legendExpanded)
        Material(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          elevation: 3,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // العنوان مع زر الإغلاق
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🗺️ دليل الخريطة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _legendExpanded = false),
                    ),
                  ],
                ),
                const Divider(height: 8),

                // المقاطعات
                const Text('المقاطعات:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 2),
                ..._districts.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: d.color,
                          borderRadius: BorderRadius.circular(2)
                        )
                      ),
                      const SizedBox(width: 4),
                      Text(d.nameAr, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                )),

                const SizedBox(height: 4),

                // نقاط الاهتمام
                const Text('نقاط الاهتمام:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 2),
                const Text('🍽️ مطاعم  🏨 فنادق', style: TextStyle(fontSize: 9)),
                const Text('🛒 أسواق  ⛽ وقود', style: TextStyle(fontSize: 9)),
                const Text('🏥 مستشفيات  🎓 تعليم', style: TextStyle(fontSize: 9)),
                const Text('🏦 بنوك  🕌 مساجد', style: TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
    ],
  );
}
```

**موقع التعديل:**
```dart
// في build() method، استبدل:
Positioned(
  left: 8,
  bottom: 245,
  child: _buildLegend(),
),

// بـ:
Positioned(
  left: 8,
  bottom: 245,
  child: _buildCollapsibleLegend(),
),
```

---

### التغيير 2: تصغير البانل السفلي

**الحالة الحالية:**
- البانل السفلي يأخذ ~200px ارتفاع
- padding كبير (20px)
- أزرار كبيرة

**الحالة المطلوبة:**
- تقليل الارتفاع إلى ~140px
- padding أصغر (12px)
- أزرار أكثر إحكامًا

**الكود:**

```dart
// في build() method، استبدل Positioned bottom panel:
Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, -2)
        )
      ],
    ),
    padding: const EdgeInsets.all(12),  // كان 20
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: _kGreen, size: 20),  // كان 24
            const SizedBox(width: 8),  // كان 12
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الموقع المحدد',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),  // كان 12
                  const SizedBox(height: 2),  // كان 4
                  _isLoadingAddress
                    ? _buildAddressShimmer()
                    : Text(
                        _selectedAddress,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),  // كان 14
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                ],
              ),
            ),
            if (_isLoadingAddress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)
              ),
          ],
        ),
        if (_selectedPosition != null) ...[
          const SizedBox(height: 6),  // كان 8
          Text(
            'الإحداثيات: ${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),  // كان 11
          ),
        ],
        const SizedBox(height: 12),  // كان 20
        ElevatedButton(
          onPressed: _isLoadingAddress ? null : _confirmSelection,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),  // كان 16
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),  // كان 12
          ),
          child: const Text('تأكيد الموقع',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),  // كان 16
        ),
        if (_selectedPosition != null) ...[
          const SizedBox(height: 8),  // كان 12
          OutlinedButton.icon(
            onPressed: _saveCurrentLocation,
            icon: const Icon(Icons.bookmark_add, size: 18),
            label: const Text('حفظ هذا الموقع', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kGreen,
              side: const BorderSide(color: _kGreen),
              padding: const EdgeInsets.symmetric(vertical: 10),  // كان 12
            ),
          ),
        ],
      ],
    ),
  ),
),
```

**النتيجة:** البانل السفلي أصبح ~140px بدلاً من 200px = **توفير 60px للخريطة**

---

### التغيير 3: تحسين البحث بإضافة قاعدة بيانات للأماكن الشهيرة

**إضافة فئة جديدة للأماكن الشهيرة:**

```dart
// إضافة في أعلى الملف مع الـ constants
class _HotSpot {
  final String nameAr;
  final String nameFr;
  final LatLng position;
  final String category;
  final String icon;

  const _HotSpot(this.nameAr, this.nameFr, this.position, this.category, this.icon);
}

// قاعدة بيانات الأماكن الساخنة / النقاط المهمة
const _hotSpots = <_HotSpot>[
  // مواقف المشاكل (أماكن الانتظار للسائقين)
  _HotSpot('موقف المشاكل - السوق الخماسي', 'Station Marché 5',
    LatLng(18.0845, -15.9815), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - السوق المركزي', 'Station Marché Central',
    LatLng(18.0800, -15.9755), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - المطار', 'Station Aéroport',
    LatLng(18.125, -15.960), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - الميناء', 'Station Port',
    LatLng(18.130, -15.970), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - الجامعة', 'Station Université',
    LatLng(18.0860, -15.9700), 'موقف', '🚖'),

  // نقاط ساخنة (مناطق ذروة الطلب)
  _HotSpot('نقطة ساخنة - تفرغ زينة', 'Hot Spot Tevragh-Zeina',
    LatLng(18.105, -15.972), 'نقطة ساخنة', '🔥'),
  _HotSpot('نقطة ساخنة - الميناء', 'Hot Spot El-Mina',
    LatLng(18.075, -15.975), 'نقطة ساخنة', '🔥'),
  _HotSpot('نقطة ساخنة - السبخة', 'Hot Spot Sebkha',
    LatLng(18.045, -15.975), 'نقطة ساخنة', '🔥'),

  // معالم إضافية
  _HotSpot('محطة الحافلات الرئيسية', 'Gare Routière',
    LatLng(18.082, -15.978), 'محطة', '🚌'),
  _HotSpot('السوق الكبير', 'Grand Marché',
    LatLng(18.085, -15.980), 'سوق', '🛍️'),
];
```

**تحسين دالة البحث:**

```dart
Future<void> _performSearch(String query) async {
  if (query.isEmpty) {
    setState(() => _searchResults = []);
    return;
  }

  setState(() => _isSearching = true);
  final results = <_SearchResult>[];
  final q = query.toLowerCase();
  final qAr = query; // للبحث بالعربية

  // 1. البحث في مواقف المشاكل والنقاط الساخنة (أولوية عالية)
  for (final h in _hotSpots) {
    if (h.nameAr.contains(qAr) ||
        h.nameFr.toLowerCase().contains(q) ||
        h.category.contains(qAr)) {
      results.add(_SearchResult(
        '${h.icon} ${h.nameAr} (${h.category})',
        h.position,
        'hotspot'
      ));
    }
  }

  // 2. البحث في المقاطعات
  for (final d in _districts) {
    if (d.nameAr.contains(qAr) || d.nameFr.toLowerCase().contains(q)) {
      results.add(_SearchResult(
        'مقاطعة ${d.nameAr}',
        d.center,
        'district'
      ));
    }
  }

  // 3. البحث في نقاط الاهتمام
  for (final p in _pois) {
    if (p.nameAr.contains(qAr) || p.nameFr.toLowerCase().contains(q)) {
      results.add(_SearchResult(
        '${p.icon} ${p.nameAr}',
        p.position,
        'poi'
      ));
    }
  }

  // 4. البحث في المواقع المحفوظة (من Firestore)
  for (final saved in _savedLocations) {
    final name = saved['name'] as String;
    final address = saved['address'] as String;
    if (name.contains(qAr) || address.contains(qAr)) {
      results.add(_SearchResult(
        '📌 $name',
        LatLng(saved['latitude'] as double, saved['longitude'] as double),
        'saved'
      ));
    }
  }

  // 5. إذا لم نجد نتائج كافية، استخدم Nominatim
  if (results.length < 3) {
    results.addAll(await _searchNominatim(query));
  }

  if (mounted) {
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }
}
```

**تحسين عرض نتائج البحث:**

```dart
// في بناء قائمة النتائج
ListTile(
  dense: true,
  leading: Icon(
    r.type == 'hotspot' ? Icons.local_taxi
      : r.type == 'district' ? Icons.map
      : r.type == 'poi' ? Icons.place
      : r.type == 'saved' ? Icons.bookmark
      : Icons.location_on,
    color: r.type == 'hotspot' ? Colors.orange
      : r.type == 'saved' ? _kGreen
      : _kGreen,
    size: 20,
  ),
  title: Text(
    r.displayName,
    style: TextStyle(
      fontSize: 12,
      fontWeight: r.type == 'hotspot' ? FontWeight.bold : FontWeight.normal
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis
  ),
  onTap: () async {
    // تكبير أكبر للنقاط الساخنة
    final zoom = r.type == 'hotspot' ? 17.0
      : r.type == 'district' ? 14.0
      : 16.0;

    _mapController.move(r.position, zoom);
    setState(() {
      _selectedPosition = r.position;
      _selectedAddress = 'جار تحديد العنوان...';
      _isLoadingAddress = true;
      _searchResults = [];
    });
    _searchController.clear();

    final address = await _getAddressFromLatLng(
      r.position.latitude,
      r.position.longitude
    );

    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    }
  },
),
```

---

### التغيير 4: إضافة اختصارات سريعة للبحث

**إضافة أزرار اختصار أعلى البحث:**

```dart
// بعد TextField البحث مباشرة
if (_searchResults.isEmpty && _searchController.text.isEmpty)
  Container(
    margin: const EdgeInsets.only(top: 4),
    height: 32,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _quickSearchChip('🚖 مواقف', 'موقف المشاكل'),
        _quickSearchChip('🔥 نقاط ساخنة', 'نقطة ساخنة'),
        _quickSearchChip('🍽️ مطاعم', 'مطعم'),
        _quickSearchChip('🏨 فنادق', 'فندق'),
        _quickSearchChip('⛽ وقود', 'محطة وقود'),
        _quickSearchChip('🏥 مستشفيات', 'مستشفى'),
      ],
    ),
  ),

// دالة إنشاء Chip
Widget _quickSearchChip(String label, String searchTerm) {
  return Padding(
    padding: const EdgeInsets.only(left: 6),
    child: ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: () {
        _searchController.text = searchTerm;
        _performSearch(searchTerm);
      },
      backgroundColor: Colors.white,
      side: BorderSide(color: _kGreen.withOpacity(0.3)),
    ),
  );
}
```

---

## ملخص التحسينات

### مساحة الخريطة

| قبل | بعد | المكسب |
|-----|-----|--------|
| دليل ثابت: 160×200px | أيقونة: 40×40px | **+32,000px² مساحة خريطة** |
| بانل سفلي: 200px | بانل سفلي: 140px | **+60px ارتفاع** |
| **المجموع** | | **~40% زيادة في مساحة الخريطة** |

### البحث الذكي

✅ **5 مصادر بحث:**
1. مواقف المشاكل (8 مواقع)
2. النقاط الساخنة (3 مناطق)
3. المقاطعات (9 مناطق)
4. نقاط الاهتمام (25 موقع)
5. المواقع المحفوظة (من Firestore)
6. Nominatim API (احتياطي)

✅ **اختصارات سريعة:**
- 6 أزرار اختصار للبحث السريع

✅ **أولويات البحث:**
1. مواقف المشاكل (أولوية قصوى)
2. النقاط الساخنة
3. المقاطعات
4. نقاط الاهتمام
5. المواقع المحفوظة
6. Nominatim

---

## التطبيق خطوة بخطوة

### الخطوة 1: دليل الخريطة القابل للطي
```bash
# نفذ التغييرات في _buildCollapsibleLegend()
# أضف state variable: bool _legendExpanded = false
# استبدل استدعاء _buildLegend() بـ _buildCollapsibleLegend()
```

### الخطوة 2: تصغير البانل السفلي
```bash
# قلل padding من 20 إلى 12
# قلل أحجام الخطوط والأيقونات
# قلل المسافات بين العناصر
```

### الخطوة 3: إضافة قاعدة بيانات الأماكن
```bash
# أضف class _HotSpot
# أضف const _hotSpots مع جميع المواقف والنقاط الساخنة
```

### الخطوة 4: تحسين البحث
```bash
# حدّث _performSearch() للبحث في _hotSpots أولاً
# أضف أولويات للنتائج
# أضف أيقونات مميزة لكل نوع
```

### الخطوة 5: إضافة الاختصارات
```bash
# أضف _quickSearchChip()
# أضف ListView أفقي بالاختصارات
```

---

## اختبار التحسينات

### اختبار 1: مساحة الخريطة
- [ ] الخريطة تحتل 40% مساحة أكثر
- [ ] دليل الخريطة يبدأ مطويًا
- [ ] البانل السفلي أصغر بـ 60px

### اختبار 2: البحث الذكي
- [ ] كتابة "موقف" → تظهر جميع المواقف
- [ ] كتابة "نقطة ساخنة" → تظهر النقاط الساخنة
- [ ] كتابة "مطعم" → تظهر المطاعم
- [ ] اختيار نتيجة → الانتقال تلقائيًا

### اختبار 3: الاختصارات
- [ ] 6 أزرار اختصار تظهر
- [ ] الضغط يبحث مباشرة
- [ ] النتائج صحيحة

---

## التقدير الزمني

| المهمة | الوقت المتوقع |
|--------|---------------|
| دليل قابل للطي | 10 دقائق |
| تصغير البانل | 5 دقائق |
| قاعدة بيانات الأماكن | 15 دقيقة |
| تحسين البحث | 10 دقائق |
| الاختصارات | 10 دقائق |
| **المجموع** | **50 دقيقة** |

---

هل تريد أن أبدأ بتنفيذ هذه التحسينات؟
