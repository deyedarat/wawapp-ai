import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../l10n/app_localizations.dart';
import '../../core/location/location_service.dart';
import 'models/order.dart' as app_order;
import 'widgets/order_tracking_view.dart';

class TrackScreen extends ConsumerStatefulWidget {
  final app_order.Order? order;
  const TrackScreen({super.key, this.order});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  StreamSubscription? _positionSubscription;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  LatLng? _currentPosition;
  String? _orderId;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _startOrderTracking();
  }

  void _startOrderTracking() async {
    if (widget.order == null) return;

    final user = await FirebaseFirestore.instance
        .collection('orders')
        .where('ownerId', isEqualTo: widget.order!.status)
        .limit(1)
        .get();

    if (user.docs.isEmpty) return;
    _orderId = user.docs.first.id;

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(_orderId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _hasNavigated) return;

      final data = snapshot.data();
      if (data == null) return;

      final statusStr = data['status'] as String?;
      if (statusStr != null) {
        final status = OrderStatus.fromFirestore(statusStr);
        if (status == OrderStatus.accepted && !_hasNavigated) {
          _hasNavigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/driver-found/$_orderId');
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _positionSubscription = LocationService.getPositionStream().listen(
      (position) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      },
    );
  }





  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(kReleaseMode ? l10n.track : '${l10n.track} • DEBUG'),
        ),
        body: SafeArea(
          child: OrderTrackingView(
            order: widget.order,
            currentPosition: _currentPosition,
            readOnly: false,
          ),
        ),
      ),
    );
  }
}
