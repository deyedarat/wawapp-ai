/// Topup Request Provider
///
/// Manages driver top-up requests state using Riverpod
/// Integrates with Cloud Functions: createTopupRequest
///
/// Author: WawApp Development Team
/// Last Updated: 2025-12-30

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Topup request model
class TopupRequest {
  final String id;
  final String driverId;
  final double amount;
  final String status; // pending, approved, rejected
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? adminId;
  final String? notes;

  const TopupRequest({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.adminId,
    this.notes,
  });

  factory TopupRequest.fromJson(Map<String, dynamic> json) {
    return TopupRequest(
      id: json['id'] as String,
      driverId: json['driverId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
      adminId: json['adminId'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverId': driverId,
        'amount': amount,
        'status': status,
        'requestedAt': requestedAt.toIso8601String(),
        if (processedAt != null) 'processedAt': processedAt!.toIso8601String(),
        if (adminId != null) 'adminId': adminId,
        if (notes != null) 'notes': notes,
      };
}

/// Topup request state
class TopupRequestState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final TopupRequest? lastRequest;

  const TopupRequestState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.lastRequest,
  });

  TopupRequestState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    TopupRequest? lastRequest,
  }) {
    return TopupRequestState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      lastRequest: lastRequest ?? this.lastRequest,
    );
  }
}

/// Topup request notifier
class TopupRequestNotifier extends StateNotifier<TopupRequestState> {
  TopupRequestNotifier() : super(const TopupRequestState());

  /// Create a new top-up request
  Future<void> createTopupRequest(double amount) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      // Call Cloud Function
      final callable =
          FirebaseFunctions.instance.httpsCallable('createTopupRequest');
      final result = await callable.call<Map<String, dynamic>>({
        'amount': amount,
      });

      final data = result.data;

      if (data['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          successMessage:
              'تم إرسال طلب الشحن بنجاح. سيتم مراجعته من قبل الإدارة.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: data['message'] as String? ?? 'فشل إنشاء طلب الشحن',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'يجب تسجيل الدخول أولاً';
          break;
        case 'invalid-argument':
          errorMessage = e.message ?? 'المبلغ المدخل غير صحيح';
          break;
        case 'permission-denied':
          errorMessage = 'ليس لديك صلاحية لإنشاء طلب شحن';
          break;
        default:
          errorMessage = 'حدث خطأ: ${e.message ?? e.code}';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'حدث خطأ غير متوقع: ${e.toString()}',
      );
    }
  }

  /// Clear messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

/// Provider for topup request state
final topupRequestProvider =
    StateNotifierProvider<TopupRequestNotifier, TopupRequestState>((ref) {
  return TopupRequestNotifier();
});
