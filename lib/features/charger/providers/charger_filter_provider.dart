import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChargerFilter {
  final String? connectorType;
  final double? maxPrice;
  final bool availableOnly;

  ChargerFilter({
    this.connectorType,
    this.maxPrice,
    this.availableOnly = false,
  });

  ChargerFilter copyWith({
    String? connectorType,
    double? maxPrice,
    bool? availableOnly,
    bool clearConnectorType = false,
    bool clearMaxPrice = false,
  }) {
    return ChargerFilter(
      connectorType: clearConnectorType
          ? null
          : (connectorType ?? this.connectorType),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }
}

class ChargerFilterNotifier extends Notifier<ChargerFilter> {
  @override
  ChargerFilter build() {
    return ChargerFilter();
  }

  void updateState(ChargerFilter newFilter) {
    state = newFilter;
  }
}

final chargerFilterProvider =
    NotifierProvider<ChargerFilterNotifier, ChargerFilter>(
      ChargerFilterNotifier.new,
    );
