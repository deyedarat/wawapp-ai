import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../l10n/app_localizations.dart';
import '../../core/location/location_service.dart';

import 'widgets/order_tracking_view.dart';

class TrackScreen extends ConsumerStatefulWidget {
  final Order? order;
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

  void _startOrderTracking() {
    if (widget.order == null) {
      debugPrint('[TRACK] No order provided to track');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('[TRACK] User not authenticated');
      return;
    }

    // Verify user owns this order
    if (widget.order!.ownerId != currentUser.uid) {
      debugPrint(
          '[TRACK] User tried to track an order they do not own: orderId=${widget.order!.id}, ownerId=${widget.order!.ownerId}, uid=${currentUser.uid}');
      return;
    }

    _orderId = widget.order!.id;

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
        } else if (status == OrderStatus.completed && !_hasNavigated) {
          _hasNavigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/trip-completed/$_orderId');
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
