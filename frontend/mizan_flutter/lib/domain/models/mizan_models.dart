import '../../core/money/money_minor.dart';

enum PaymentMode { gatewayPreAuth, cash, credit, partialCredit }
enum FaultCategory { seller, buyer, neutral }
enum StoreVisibility { privateOnly, qrOnly, publicSearch }

class CatalogItem {
  final String id;
  final String orgId;
  final String sku;
  final String name;
  final MoneyMinor salePrice;
  final bool isPerishable;
  final int qtyAvailableMinor;

  const CatalogItem({
    required this.id,
    required this.orgId,
    required this.sku,
    required this.name,
    required this.salePrice,
    required this.isPerishable,
    required this.qtyAvailableMinor,
  });

  int get disputeWindowMinutes => isPerishable ? 30 : 1440;
}

class LiveCartLine {
  final CatalogItem item;
  final int qtyMinor; // x10000 (1 unit = 10000)

  const LiveCartLine({required this.item, required this.qtyMinor});

  MoneyMinor get lineTotal => item.salePrice.multiplyByQtyMinor(qtyMinor);
}

class DisputeEvidencePacket {
  final String orderId;
  final String mediaSha256;
  final DateTime capturedAtUtc;
  final double gpsLat;
  final double gpsLng;
  final bool capturedViaLiveInAppCamera;
  final String reasonCode;
  final FaultCategory faultCategory;

  const DisputeEvidencePacket({
    required this.orderId,
    required this.mediaSha256,
    required this.capturedAtUtc,
    required this.gpsLat,
    required this.gpsLng,
    required this.capturedViaLiveInAppCamera,
    required this.reasonCode,
    required this.faultCategory,
  });
}

/// Client-side anti-fraud guard mirroring backend `P2PCommerceService.CanOpenDispute`.
class DisputeAntiFraudGuard {
  static ({bool allowed, String reason}) validate({
    required DateTime? deliveredAtUtc,
    required DateTime nowUtc,
    required bool isPerishable,
    required bool isLiveInAppCamera,
  }) {
    if (!isLiveInAppCamera) {
      return (allowed: false, reason: 'GALLERY_UPLOAD_BLOCKED');
    }
    if (deliveredAtUtc == null) {
      return (allowed: false, reason: 'ORDER_NOT_DELIVERED');
    }
    final windowMinutes = isPerishable ? 30 : 1440;
    final elapsedMinutes = nowUtc.difference(deliveredAtUtc).inMinutes;
    if (elapsedMinutes > windowMinutes) {
      return (allowed: false, reason: 'DISPUTE_WINDOW_EXPIRED');
    }
    return (allowed: true, reason: 'ELIGIBLE');
  }
}
