import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/tramite_model.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final Tramite tramite;
  const PaymentScreen({super.key, required this.tramite});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final bool _isLoading = false;

  Future<void> _abrirPasarela() async {
    if (widget.tramite.invoiceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay factura disponible para este trámite'),
        ),
      );
      return;
    }

    final Uri url = Uri.parse(widget.tramite.invoiceUrl!);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la pasarela de pago')),
        );
      }
    } else {
      if (mounted) {
        context.go('/home'); // Regresar al dashboard después de abrir el link
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pasarela USDT / USDC')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.currency_bitcoin,
                    size: 64,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pago Requerido',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trámite: ${widget.tramite.nombrePlantilla}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Se abrirá la pasarela de CoinGate para realizar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _abrirPasarela,
                      child: const Text(
                        'Pagar Ya en CoinGate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text(
                      'Pagar más tarde',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
