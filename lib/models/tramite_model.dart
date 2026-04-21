class Tramite {
  final String id;
  final String plantillaId;
  final String nombrePlantilla;
  final String estadoGlobal;
  final String? pasoActualId;

  Tramite({
    required this.id,
    required this.plantillaId,
    required this.nombrePlantilla,
    required this.estadoGlobal,
    this.pasoActualId,
  });

  factory Tramite.fromJson(Map<String, dynamic> json) {
    return Tramite(
      id: json['id'] ?? '',
      plantillaId: json['plantillaId'] ?? '',
      nombrePlantilla: json['nombrePlantilla'] ?? '',
      estadoGlobal: json['estadoGlobal'] ?? 'PENDIENTE',
      pasoActualId: json['pasoActualId'],
    );
  }
}
