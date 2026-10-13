import '../l10n/app_localizations.dart';

enum ShopItemType {
  equipment,
  supplement,
  giftCard;

  static ShopItemType fromString(String v) => switch (v) {
    'equipment' => ShopItemType.equipment,
    'supplement' => ShopItemType.supplement,
    'gift_card' => ShopItemType.giftCard,
    _ => ShopItemType.equipment,
  };

  String get apiValue => switch (this) {
    ShopItemType.equipment => 'equipment',
    ShopItemType.supplement => 'supplement',
    ShopItemType.giftCard => 'gift_card',
  };

  String label(AppLocalizations l10n) => switch (this) {
    ShopItemType.equipment => l10n.businessItemTypeEquipment,
    ShopItemType.supplement => l10n.businessItemTypeSupplement,
    ShopItemType.giftCard => l10n.businessItemTypeGiftCard,
  };
}

class ShopItem {
  final String id;
  final String shopId;
  final ShopItemType type;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final bool isActive;
  final DateTime? activeUntil;
  final String? imageUrl;

  const ShopItem({
    required this.id,
    required this.shopId,
    required this.type,
    required this.name,
    this.description,
    required this.price,
    required this.quantity,
    required this.isActive,
    this.activeUntil,
    this.imageUrl,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] as String,
    shopId: json['shop_id'] as String,
    type: ShopItemType.fromString(json['type'] as String),
    name: json['name'] as String,
    description: json['description'] as String?,
    price: double.parse(json['price'].toString()),
    quantity: json['quantity'] as int? ?? 1,
    isActive: json['is_active'] as bool? ?? true,
    activeUntil: json['active_until'] != null
        ? DateTime.tryParse(json['active_until'] as String)
        : null,
    imageUrl: json['image_url'] as String?,
  );
}
