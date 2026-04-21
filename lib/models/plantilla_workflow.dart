class PasoWorkflow {
  final String id;
  final String tipo;
  final String? departamentoId;
  final String nombrePaso;
  final Map<String, dynamic>? formularioJson;
  final Map<String, dynamic>? siguientes;

  PasoWorkflow({
    required this.id,
    required this.tipo,
    this.departamentoId,
    required this.nombrePaso,
    this.formularioJson,
    this.siguientes,
  });

  factory PasoWorkflow.fromJson(Map<String, dynamic> json) {
    return PasoWorkflow(
      id: json['id'] ?? '',
      tipo: json['tipo'] ?? 'ACTIVIDAD',
      departamentoId: json['departamentoId'],
      nombrePaso: json['nombrePaso'] ?? 'Paso',
      formularioJson: json['formularioJson'],
      siguientes: json['siguientes'],
    );
  }
}

class PlantillaWorkflow {
  final String id;
  final String nombre;
  final String descripcion;
  final bool isActive;
  final String categoria;
  final double costoBase;
  final Map<String, dynamic>? formularioCliente;
  final List<PasoWorkflow> pasos;

  PlantillaWorkflow({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.isActive,
    required this.categoria,
    required this.costoBase,
    this.formularioCliente,
    this.pasos = const [],
  });

  factory PlantillaWorkflow.fromJson(Map<String, dynamic> json) {
    return PlantillaWorkflow(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      isActive: json['isActive'] ?? false,
      categoria: json['categoria'] ?? 'EXTERNO',
      costoBase: (json['costoBase'] ?? 0.0).toDouble(),
      formularioCliente: json['formularioCliente'],
      pasos: (json['pasos'] as List<dynamic>?)
              ?.map((e) => PasoWorkflow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
