class Tramite {
  final String id;
  final String plantillaId;
  final String nombrePlantilla;
  final String estadoGlobal;
  final String? pasoActualId;
  final String? paymentId;
  final String? invoiceUrl;

  Tramite({
    required this.id,
    required this.plantillaId,
    required this.nombrePlantilla,
    required this.estadoGlobal,
    this.pasoActualId,
    this.paymentId,
    this.invoiceUrl,
  });

  factory Tramite.fromJson(Map<String, dynamic> json) {
    return Tramite(
      id: json['id'] ?? '',
      plantillaId: json['plantillaId'] ?? '',
      nombrePlantilla: json['nombrePlantilla'] ?? '',
      estadoGlobal: json['estadoGlobal'] ?? 'PENDIENTE',
      pasoActualId: json['pasoActualId'],
      paymentId: json['paymentId'],
      invoiceUrl: json['invoiceUrl'],
    );
  }
}
