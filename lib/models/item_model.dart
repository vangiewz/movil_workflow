/// Modelo de datos para los elementos de la lista
/// Patrón: Data Model - Representa una entidad de negocio
class ItemModel {
  final int id;
  final String title;
  final String description;
  final String category;
  final DateTime createdAt;

  /// Constructor con parámetros nombrados para mayor claridad
  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.createdAt,
  });

  /// Constructor factory para crear desde JSON
  /// Patrón: Factory - Facilita la creación desde APIs
  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convertir el modelo a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Método copyWith para crear una copia con cambios
  /// Patrón: Immutability - Facilita seguimiento de cambios
  ItemModel copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    DateTime? createdAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ItemModel(id: $id, title: $title, category: $category)';
}
