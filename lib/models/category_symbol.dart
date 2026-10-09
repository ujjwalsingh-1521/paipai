import 'package:flutter/material.dart';

/// What a category stores as its symbol (the `emoji` column): either
/// `icon:<name>` for one of the icons below, or any emoji the user typed.
abstract final class CategorySymbol {
  static const _prefix = 'icon:';

  static String icon(String name) => '$_prefix$name';

  /// The Material icon for [symbol], or null if it's an emoji.
  static IconData? iconFor(String symbol) =>
      symbol.startsWith(_prefix) ? icons[symbol.substring(_prefix.length)] : null;

  /// Every icon, by name. Names are stored in the database: never rename one.
  static final Map<String, IconData> icons = {
    for (final group in groups) ...group.icons,
  };

  /// The picker's sections, in order.
  static final List<({String title, Map<String, IconData> icons})> groups = [
    (title: 'Food & drink', icons: {
      'restaurant': Icons.restaurant_rounded,
      'fastfood': Icons.fastfood_rounded,
      'delivery_dining': Icons.delivery_dining_rounded,
      'local_cafe': Icons.local_cafe_rounded,
      'local_pizza': Icons.local_pizza_rounded,
      'ramen_dining': Icons.ramen_dining_rounded,
      'bakery_dining': Icons.bakery_dining_rounded,
      'icecream': Icons.icecream_rounded,
      'cake': Icons.cake_rounded,
      'local_bar': Icons.local_bar_rounded,
      'sports_bar': Icons.sports_bar_rounded,
    }),
    (title: 'Groceries & home needs', icons: {
      'local_grocery_store': Icons.local_grocery_store_rounded,
      'shopping_basket': Icons.shopping_basket_rounded,
      'egg': Icons.egg_rounded,
      'kitchen': Icons.kitchen_rounded,
      'rice_bowl': Icons.rice_bowl_rounded,
      'set_meal': Icons.set_meal_rounded,
      'local_drink': Icons.local_drink_rounded,
      'eco': Icons.eco_rounded,
      'soap': Icons.soap_rounded,
      'cleaning_services': Icons.cleaning_services_rounded,
    }),
    (title: 'Getting around', icons: {
      'commute': Icons.commute_rounded,
      'directions_bus': Icons.directions_bus_rounded,
      'train': Icons.train_rounded,
      'subway': Icons.subway_rounded,
      'local_taxi': Icons.local_taxi_rounded,
      'electric_rickshaw': Icons.electric_rickshaw_rounded,
      'two_wheeler': Icons.two_wheeler_rounded,
      'directions_car': Icons.directions_car_rounded,
      'local_gas_station': Icons.local_gas_station_rounded,
      'ev_station': Icons.ev_station_rounded,
      'local_parking': Icons.local_parking_rounded,
      'pedal_bike': Icons.pedal_bike_rounded,
      'car_repair': Icons.car_repair_rounded,
    }),
    (title: 'Travel', icons: {
      'luggage': Icons.luggage_rounded,
      'flight': Icons.flight_rounded,
      'hotel': Icons.hotel_rounded,
      'beach_access': Icons.beach_access_rounded,
      'landscape': Icons.landscape_rounded,
      'map': Icons.map_rounded,
      'directions_boat': Icons.directions_boat_rounded,
      'tour': Icons.tour_rounded,
    }),
    (title: 'Home & bills', icons: {
      'receipt_long': Icons.receipt_long_rounded,
      'home': Icons.home_rounded,
      'bolt': Icons.bolt_rounded,
      'water_drop': Icons.water_drop_rounded,
      'propane_tank': Icons.propane_tank_rounded,
      'wifi': Icons.wifi_rounded,
      'smartphone': Icons.smartphone_rounded,
      'tv': Icons.tv_rounded,
      'chair': Icons.chair_rounded,
      'handyman': Icons.handyman_rounded,
      'local_laundry_service': Icons.local_laundry_service_rounded,
    }),
    (title: 'Shopping', icons: {
      'shopping_bag': Icons.shopping_bag_rounded,
      'local_mall': Icons.local_mall_rounded,
      'checkroom': Icons.checkroom_rounded,
      'devices': Icons.devices_rounded,
      'headphones': Icons.headphones_rounded,
      'watch': Icons.watch_rounded,
      'diamond': Icons.diamond_rounded,
      'face_retouching_natural': Icons.face_retouching_natural_rounded,
      'content_cut': Icons.content_cut_rounded,
      'card_giftcard': Icons.card_giftcard_rounded,
    }),
    (title: 'Health & fitness', icons: {
      'medical_services': Icons.medical_services_rounded,
      'medication': Icons.medication_rounded,
      'local_hospital': Icons.local_hospital_rounded,
      'monitor_heart': Icons.monitor_heart_rounded,
      'vaccines': Icons.vaccines_rounded,
      'health_and_safety': Icons.health_and_safety_rounded,
      'fitness_center': Icons.fitness_center_rounded,
      'self_improvement': Icons.self_improvement_rounded,
      'directions_run': Icons.directions_run_rounded,
      'spa': Icons.spa_rounded,
    }),
    (title: 'Fun', icons: {
      'movie': Icons.movie_rounded,
      'subscriptions': Icons.subscriptions_rounded,
      'sports_esports': Icons.sports_esports_rounded,
      'music_note': Icons.music_note_rounded,
      'sports_cricket': Icons.sports_cricket_rounded,
      'sports_soccer': Icons.sports_soccer_rounded,
      'theater_comedy': Icons.theater_comedy_rounded,
      'celebration': Icons.celebration_rounded,
      'local_activity': Icons.local_activity_rounded,
      'photo_camera': Icons.photo_camera_rounded,
      'palette': Icons.palette_rounded,
    }),
    (title: 'Learning & work', icons: {
      'school': Icons.school_rounded,
      'menu_book': Icons.menu_book_rounded,
      'laptop': Icons.laptop_rounded,
      'work': Icons.work_rounded,
      'business_center': Icons.business_center_rounded,
      'storefront': Icons.storefront_rounded,
      'edit_note': Icons.edit_note_rounded,
      'science': Icons.science_rounded,
      'backpack': Icons.backpack_rounded,
    }),
    (title: 'Money', icons: {
      'payments': Icons.payments_rounded,
      'account_balance_wallet': Icons.account_balance_wallet_rounded,
      'account_balance': Icons.account_balance_rounded,
      'savings': Icons.savings_rounded,
      'credit_card': Icons.credit_card_rounded,
      'currency_rupee': Icons.currency_rupee_rounded,
      'trending_up': Icons.trending_up_rounded,
      'request_quote': Icons.request_quote_rounded,
      'autorenew': Icons.autorenew_rounded,
      'handshake': Icons.handshake_rounded,
      'sell': Icons.sell_rounded,
      'house': Icons.house_rounded,
    }),
    (title: 'People & life', icons: {
      'family_restroom': Icons.family_restroom_rounded,
      'child_care': Icons.child_care_rounded,
      'pets': Icons.pets_rounded,
      'volunteer_activism': Icons.volunteer_activism_rounded,
      'favorite': Icons.favorite_rounded,
      'local_florist': Icons.local_florist_rounded,
      'temple_hindu': Icons.temple_hindu_rounded,
      'build': Icons.build_rounded,
      'more_horiz': Icons.more_horiz_rounded,
      'auto_awesome': Icons.auto_awesome_rounded,
    }),
  ];

  /// Symbol for a category whose own one is unknown (e.g. deleted).
  static final fallback = icon('more_horiz');

  /// Up to 1.3.0 a symbol was always one of these emoji, drawn as itself;
  /// 1.4.0 drew them as icons. Upgrades and old backups convert them to the
  /// matching `icon:` symbol, so only emoji typed since then show as emoji.
  static const _legacyEmoji = {
    '🍔': 'fastfood', '🍕': 'local_pizza', '🍣': 'set_meal', '☕': 'local_cafe',
    '🍺': 'sports_bar', '🎂': 'cake', '🍩': 'bakery_dining', '🥗': 'rice_bowl',
    '🚗': 'directions_car', '🚕': 'local_taxi', '✈️': 'flight', '🚆': 'train',
    '🛵': 'two_wheeler', '⛽': 'local_gas_station', '🚌': 'directions_bus', '🚲': 'pedal_bike',
    '🛍️': 'shopping_bag', '👗': 'checkroom', '👟': 'directions_run', '💄': 'face_retouching_natural',
    '🎁': 'card_giftcard', '💎': 'diamond', '🧢': 'checkroom', '👜': 'local_mall',
    '📄': 'receipt_long', '💡': 'bolt', '📱': 'smartphone', '🏠': 'home',
    '💧': 'water_drop', '📶': 'wifi', '🔌': 'bolt', '📬': 'receipt_long',
    '🎬': 'movie', '🎮': 'sports_esports', '🎵': 'music_note', '📺': 'tv',
    '🎭': 'theater_comedy', '🎪': 'celebration', '🎤': 'music_note', '🎲': 'sports_esports',
    '💊': 'medication', '🏥': 'local_hospital', '🧘': 'self_improvement', '💪': 'fitness_center',
    '🩺': 'monitor_heart', '🧴': 'soap', '🏃': 'directions_run', '🍎': 'eco',
    '📚': 'menu_book', '🎓': 'school', '✏️': 'edit_note', '💻': 'laptop',
    '🔬': 'science', '📐': 'edit_note', '🎒': 'backpack', '📝': 'edit_note',
    '💰': 'payments', '💳': 'credit_card', '🏦': 'account_balance', '📊': 'trending_up',
    '🤝': 'handshake', '🔧': 'build', '⚙️': 'build', '🛠️': 'handyman',
    '🐕': 'pets', '🌱': 'local_florist', '🎨': 'palette', '📸': 'photo_camera',
    '⚽': 'sports_soccer', '🏋️': 'fitness_center', '🎯': 'local_activity', '🧩': 'sports_esports',
    '📈': 'trending_up', '🏢': 'storefront', '🔄': 'autorenew', '✨': 'more_horiz',
  };

  /// [symbol] as stored from 1.4.0 on. Rows named like a default category
  /// get that default's (better) icon, e.g. Food → fork and knife.
  static String upgradeLegacy(String symbol, String name, Map<String, String> defaultsByName) {
    final legacy = _legacyEmoji[symbol];
    if (legacy == null) return symbol;
    return defaultsByName[name.trim().toLowerCase()] ?? icon(legacy);
  }
}

/// Data version 8: category and income-source rows from before it get
/// `icon:` symbols. Used by the database upgrade and by restore of older
/// backups. Returns new row maps; other columns are untouched.
List<Map<String, Object?>> upgradeSymbolRows(
    List<Map<String, Object?>> rows, List<Map<String, dynamic>> defaults) {
  final defaultsByName = {
    for (final d in defaults) (d['name'] as String).toLowerCase(): d['emoji'] as String,
  };
  return [
    for (final row in rows)
      {
        ...row,
        'emoji': CategorySymbol.upgradeLegacy(
            row['emoji'] as String, row['name'] as String, defaultsByName),
      },
  ];
}
