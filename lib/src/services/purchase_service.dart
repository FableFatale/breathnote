import 'package:flutter/services.dart';

const String kProLifetimeProductId = 'breathnote_pro_lifetime';

enum PurchaseStatus {
  purchased,
  restored,
  cancelled,
  notFound,
  unavailable,
  error,
}

class PurchaseResult {
  const PurchaseResult(this.status, {this.message});

  final PurchaseStatus status;
  final String? message;

  bool get unlocked =>
      status == PurchaseStatus.purchased || status == PurchaseStatus.restored;
}

/// 一次性永久买断（非消耗型内购）与恢复购买服务抽象层。
/// 通过 `app.breathnote/billing` 桥接 Google Play Billing / StoreKit，
/// 无需自建邮箱账号后端即可跨设备恢复永久买断权益。
class PurchaseService {
  const PurchaseService();

  static const _channel = MethodChannel('app.breathnote/billing');

  Future<PurchaseResult> purchaseProLifetime() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'purchaseProLifetime',
        {'productId': kProLifetimeProductId},
      );
      return switch (result) {
        'purchased' => const PurchaseResult(PurchaseStatus.purchased),
        'restored' => const PurchaseResult(PurchaseStatus.restored),
        'cancelled' => const PurchaseResult(PurchaseStatus.cancelled),
        'unavailable' => const PurchaseResult(PurchaseStatus.unavailable),
        _ => const PurchaseResult(PurchaseStatus.error),
      };
    } on MissingPluginException {
      return const PurchaseResult(PurchaseStatus.unavailable);
    } on PlatformException catch (error) {
      if (error.code == 'billing_unavailable' ||
          error.code == 'store_not_configured') {
        return const PurchaseResult(PurchaseStatus.unavailable);
      }
      if (error.code == 'user_cancelled') {
        return const PurchaseResult(PurchaseStatus.cancelled);
      }
      return PurchaseResult(PurchaseStatus.error, message: error.message);
    }
  }

  Future<PurchaseResult> restorePurchases() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'restorePurchases',
        {'productId': kProLifetimeProductId},
      );
      return switch (result) {
        'restored' => const PurchaseResult(PurchaseStatus.restored),
        'notFound' => const PurchaseResult(PurchaseStatus.notFound),
        'unavailable' => const PurchaseResult(PurchaseStatus.unavailable),
        _ => const PurchaseResult(PurchaseStatus.error),
      };
    } on MissingPluginException {
      return const PurchaseResult(PurchaseStatus.unavailable);
    } on PlatformException catch (error) {
      if (error.code == 'billing_unavailable' ||
          error.code == 'store_not_configured') {
        return const PurchaseResult(PurchaseStatus.unavailable);
      }
      return PurchaseResult(PurchaseStatus.error, message: error.message);
    }
  }
}
