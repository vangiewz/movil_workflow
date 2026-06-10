class Tramite {
  final String id;
  final String plantillaId;
  final String nombrePlantilla;
  final String estadoGlobal;
  final List<String> pasosActualesIds;
  final String? paymentId;
  final String? invoiceUrl;
  final List<dynamic>? documentos;

  Tramite({
    required this.id,
    required this.plantillaId,
    required this.nombrePlantilla,
    required this.estadoGlobal,
    required this.pasosActualesIds,
    this.paymentId,
    this.invoiceUrl,
    this.documentos,
  });

  factory Tramite.fromJson(Map<String, dynamic> json) {
    return Tramite(
      id: json['id'] ?? '',
      plantillaId: json['plantillaId'] ?? '',
      nombrePlantilla: json['nombrePlantilla'] ?? '',
      estadoGlobal: json['estadoGlobal'] ?? 'PENDIENTE',
      pasosActualesIds: (json['pasosActualesIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      paymentId: json['paymentId'],
      invoiceUrl: json['invoiceUrl'],
      documentos: json['documentos'],
    );
  }
}
