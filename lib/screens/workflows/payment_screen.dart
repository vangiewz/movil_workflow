import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import '../../services/draft_service.dart';
import 'package:go_router/go_router.dart';

class PaymentScreen extends StatefulWidget {
  final PlantillaWorkflow workflow;
  const PaymentScreen({super.key, required this.workflow});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _hashCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si no requiere pago, pasarlo directo a la creación de trámite (skip payment)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.workflow.costoBase <= 0) {
        _crearTramiteYContinuar();
      }
    });
  }

  Future<void> _crearTramiteYContinuar() async {
    setState(() => _isLoading = true);
    try {
      // Guarda en disco que ya se pagó este trámite
      await DraftService.savePaidDraft(widget.workflow);
      
      if (mounted) {
        // Redirigimos a la pantalla de llenado de formulario
        context.pushReplacement('/form', extra: widget.workflow);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _verificarPagoUSDT() async {
    if (_hashCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el Hash de Transferencia')));
      return;
    }
    
    setState(() => _isLoading = true);
    // Simular un delay de API Blockchain
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pago verificado, iniciando trámite!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      _crearTramiteYContinuar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workflow.costoBase <= 0) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pasarela USDT / USDC')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.currency_bitcoin, size: 64, color: Colors.greenAccent),
              const SizedBox(height: 16),
              Text('Pago Requerido', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text('Este trámite tiene un costo de:', style: Theme.of(context).textTheme.bodyMedium),
              Text('\$${widget.workflow.costoBase} USDT', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              const SizedBox(height: 40),

              // Wallet Info Mock
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Envía el monto exacto a la siguiente wallet (Red Tron TRC20):', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                      child: const Text('TX1uRz...MOCK...4sE92', style: TextStyle(color: AppColors.primaryLight, fontFamily: 'monospace', fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _hashCtrl,
                      decoration: const InputDecoration(labelText: 'Pega el Hash de Transacción (TXID)', alignLabelWithHint: true),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _verificarPagoUSDT,
                  child: const Text('Verificar Pago y Continuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
