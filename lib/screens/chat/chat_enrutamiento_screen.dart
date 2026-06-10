import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/workflow_service.dart';
import '../../widgets/chat_bubble_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatEnrutamientoScreen extends StatefulWidget {
  const ChatEnrutamientoScreen({Key? key}) : super(key: key);

  @override
  _ChatEnrutamientoScreenState createState() => _ChatEnrutamientoScreenState();
}

class _ChatEnrutamientoScreenState extends State<ChatEnrutamientoScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': '¡Hola! Soy tu asistente inteligente. Cuéntame qué trámite deseas realizar y te ayudaré a encontrarlo.',
      'isUser': false,
      'tramiteId': null,
    }
  ];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true, 'tramiteId': null});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await WorkflowService.enrutarChatbot(text);
      if (mounted) {
        setState(() {
          _messages.add({
            'text': response['mensaje'] ?? 'No pude procesar la respuesta',
            'isUser': false,
            'tramiteId': response['tramiteId'],
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Error al comunicarse con el servidor: $e',
            'isUser': false,
            'tramiteId': null,
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _toggleVoiceInput() async {
    if (_isLoading) return;
    
    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
         if (val == 'done' || val == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              if (_controller.text.trim().isNotEmpty) {
                _sendMessage();
              }
            }
         }
      },
      onError: (val) {
         if (mounted) {
           setState(() => _isListening = false);
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error de micrófono: ${val.errorMsg}'))
           );
         }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: 'es_ES',
        onResult: (val) {
          _controller.text = val.recognizedWords;
          // El envío automático ocurre cuando el onStatus recibe 'done'
        },
      );
    } else {
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Micrófono denegado o no compatible'))
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente de Trámites'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ChatBubbleWidget(
                  text: msg['text'],
                  isUser: msg['isUser'],
                  tramiteId: msg['tramiteId'],
                  onIniciarTramite: () async {
                    if (msg['tramiteId'] != null) {
                      try {
                        setState(() => _isLoading = true);
                        final wf = await WorkflowService.getWorkflowById(msg['tramiteId'].toString());
                        if (mounted) {
                          setState(() => _isLoading = false);
                          context.push('/form', extra: wf);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al cargar trámite: $e')),
                          );
                        }
                      }
                    }
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ej. Necesito un certificado de trabajo...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isListening ? Colors.red : AppColors.surfaceVariant,
                  child: IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.white : AppColors.textPrimary),
                    onPressed: _toggleVoiceInput,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
