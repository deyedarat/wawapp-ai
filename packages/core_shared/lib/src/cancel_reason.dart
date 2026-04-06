/// Reasons a driver can cancel an accepted order.
enum CancelReason {
  vehicleBreakdown,
  customerUnreachable,
  routeUnsafe,
  other;

  String get firestoreValue {
    switch (this) {
      case vehicleBreakdown:
        return 'vehicle_breakdown';
      case customerUnreachable:
        return 'customer_unreachable';
      case routeUnsafe:
        return 'route_unsafe';
      case other:
        return 'other';
    }
  }

  String get arabicLabel {
    switch (this) {
      case vehicleBreakdown:
        return 'تعطل السيارة';
      case customerUnreachable:
        return 'العميل لا يرد';
      case routeUnsafe:
        return 'الطريق غير آمن';
      case other:
        return 'سبب آخر';
    }
  }
}
