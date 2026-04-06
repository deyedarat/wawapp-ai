# Q TASK 4C: Display Customer Phone in UI

**Part:** C of 3
**Time:** 25 minutes

---

## Objective
Display customer phone number prominently in the active order screen with a call button.

---

## File to Modify

### `apps/wawapp_driver/lib/features/active/active_order_screen.dart`

---

## Current State

Currently at line 300-310, there's a TODO comment:
```dart
// Call customer button
if (order.ownerId != null)
  IconButton(
    icon: const Icon(Icons.phone, color: DriverAppColors.primaryLight),
    onPressed: () {
      // TODO: Get customer phone from Firestore and call
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ميزة الاتصال بالعميل قيد التطوير')),
      );
    },
    tooltip: 'اتصل بالعميل',
  ),
```

---

## Implementation

### Step 1: Remove TODO and Add Phone Card

**Remove** the TODO IconButton section (lines ~300-311).

**Add** this prominent phone card **before** the pickup/dropoff location cards (insert around line 285, right after the order details card ends):

```dart
// Customer Phone Card - PROMINENT
if (order.customerPhone != null)
  Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: const Color(0xFFF1F8E9), // Light green background
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Phone Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DriverAppColors.primaryLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.phone,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Phone Number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم العميل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.customerPhone!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.black87,
                  ),
                  textDirection: TextDirection.ltr, // Phone numbers LTR
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Call Button
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall(order.customerPhone!),
            icon: const Icon(Icons.call, size: 20),
            label: const Text('اتصل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
```

---

### Step 2: Verify `_makePhoneCall` Method Exists

The `_makePhoneCall()` method already exists (line 94-105). It should look like this:

```dart
Future<void> _makePhoneCall(String phoneNumber) async {
  final uri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إجراء المكالمة')),
      );
    }
  }
}
```

✅ This method already exists - no changes needed!

---

### Step 3: Handle Missing Phone Case (Optional)

If you want to show a message when phone is not available, add this **alternative card**:

```dart
// No Phone Available Card
if (order.customerPhone == null && order.ownerId != null)
  Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: Colors.orange.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'رقم العميل غير متوفر',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
```

---

## Complete Code Snippet

Here's how the order details section should look (around line 280-360):

```dart
// Order Details Card
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'طلب #${order.id != null && order.id!.length > 6 ? order.id!.substring(order.id!.length - 6) : order.id ?? 'N/A'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Distance and Price Summary
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المسافة: ${order.distanceKm.toStringAsFixed(1)} كم'),
            Text('السعر: ${order.price} MRU',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text('الحالة: ${order.orderStatus.toArabicLabel()}',
            style: TextStyle(color: _getStatusColor(order.orderStatus))),
      ],
    ),
  ),
),
const SizedBox(height: 16),

// ══════════════════════════════════════════════
// CUSTOMER PHONE CARD - ADD THIS HERE
// ══════════════════════════════════════════════
if (order.customerPhone != null)
  Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: const Color(0xFFF1F8E9),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DriverAppColors.primaryLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.phone,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم العميل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.customerPhone!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.black87,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall(order.customerPhone!),
            icon: const Icon(Icons.call, size: 20),
            label: const Text('اتصل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  ),

// Pickup Location Card
ListTile(
  contentPadding: EdgeInsets.zero,
  leading: const Icon(Icons.location_on, color: Colors.green),
  title: const Text('من', style: TextStyle(fontSize: 12)),
  subtitle: Text(order.pickup.label),
  // ... rest of pickup card
),
// ... rest of the screen
```

---

## Visual Design

**Layout:**
```
┌─────────────────────────────────────┐
│ [ Order Card ]                      │
│ Order #ABC123                       │
│ 5 km • 100 MRU                      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ [📞]  رقم العميل            [اتصل] │
│       +222 12 34 56 78       🟢     │
│  (Large, prominent, green bg)       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 📍 من: موقع الالتقاط               │
└─────────────────────────────────────┘
```

---

## Testing Checklist

- [ ] Accept an order
- [ ] Phone number displays in green card
- [ ] Phone number is large (20px) and bold
- [ ] Phone number shows in LTR direction (readable)
- [ ] "اتصل" button is green
- [ ] Tap call button → phone dialer opens
- [ ] Dialer shows correct customer number
- [ ] If no phone → card doesn't show (or shows "not available" message)
- [ ] flutter analyze → 0 errors

---

## Dependencies

✅ **Already installed:**
- `url_launcher` package (for `canLaunchUrl` and `launchUrl`)

No new dependencies needed!

---

## Safety

✅ **Null safety:**
- Uses `if (order.customerPhone != null)` - only shows if phone available
- `_makePhoneCall()` handles launch failure gracefully

---

## Report Back to Claude

✅ Modified: `apps/wawapp_driver/lib/features/active/active_order_screen.dart`
✅ Added: Prominent customer phone card (green background, large text)
✅ Added: Green "اتصل" call button
✅ Removed: TODO placeholder
✅ Test: Phone displays correctly and call button works
✅ `flutter analyze`: 0 errors

---

**Congratulations! Task 4 Complete!** 🎉

All parts (A, B, C) done. Customer phone now displays prominently and driver can call easily.
