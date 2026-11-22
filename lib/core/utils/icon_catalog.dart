import 'package:material_ui/material_ui.dart';

/// Catálogo de íconos seleccionables para categorías y grupos.
///
/// En la base se guarda la *clave* (texto), nunca el código del ícono, para
/// que los datos sean estables entre versiones y plataformas.
class IconCatalog {
  IconCatalog._();

  static const Map<String, IconData> icons = {
    'bolt': Icons.bolt_rounded, // UTE (electricidad)
    'home': Icons.home_rounded, // Alquiler
    'water': Icons.water_drop_rounded, // OSE (agua)
    'wifi': Icons.wifi_rounded, // ANTEL (internet/teléfono)
    'fire': Icons.local_fire_department_rounded, // Gas
    'propane': Icons.propane_tank_rounded, // Supergás
    'phone': Icons.smartphone_rounded, // Celulares
    'cart': Icons.shopping_cart_rounded,
    'food': Icons.restaurant_rounded,
    'car': Icons.directions_car_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'health': Icons.medical_services_rounded,
    'school': Icons.school_rounded,
    'pets': Icons.pets_rounded,
    'beach': Icons.beach_access_rounded,
    'tv': Icons.tv_rounded,
    'card': Icons.credit_card_rounded,
    'gift': Icons.card_giftcard_rounded,
    'tools': Icons.handyman_rounded,
    'bus': Icons.directions_bus_rounded,
    'sport': Icons.fitness_center_rounded,
    'tag': Icons.sell_rounded,
    'folder': Icons.folder_rounded,
    'category': Icons.category_rounded,
  };

  static IconData of(String? key) => icons[key] ?? Icons.category_rounded;
}
