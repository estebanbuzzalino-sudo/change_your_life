import 'package:flutter/material.dart';

class FriendScreen extends StatefulWidget {
  final String? initialRequesterName;
  final String? initialName;
  final String? initialEmail;
  final String? initialWhatsappE164;

  const FriendScreen({
    super.key,
    this.initialRequesterName,
    this.initialName,
    this.initialEmail,
    this.initialWhatsappE164,
  });

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  static final RegExp _e164Regex = RegExp(r'^\+[1-9][0-9]{7,14}$');
  static final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  late final TextEditingController requesterController;
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController whatsappController;

  @override
  void initState() {
    super.initState();
    requesterController = TextEditingController(
      text: widget.initialRequesterName ?? '',
    );
    nameController = TextEditingController(text: widget.initialName ?? '');
    emailController = TextEditingController(text: widget.initialEmail ?? '');
    whatsappController = TextEditingController(
      text: widget.initialWhatsappE164 ?? '',
    );
  }

  @override
  void dispose() {
    requesterController.dispose();
    nameController.dispose();
    emailController.dispose();
    whatsappController.dispose();
    super.dispose();
  }

  void _saveFriend() {
    final requesterName = requesterController.text.trim();
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final whatsappE164 = whatsappController.text.trim();

    if (requesterName.isEmpty) {
      _showError('Completa tu nombre y apellido.');
      return;
    }

    if (name.isEmpty) {
      _showError('Completa el nombre del amigo.');
      return;
    }

    if (whatsappE164.isNotEmpty && !_e164Regex.hasMatch(whatsappE164)) {
      _showError('WhatsApp invalido. Usa formato +5491112345678.');
      return;
    }

    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      _showError(
        'Email invalido. Revisa que tenga formato nombre@dominio.com.',
      );
      return;
    }

    if (email.isEmpty && whatsappE164.isEmpty) {
      _showError('Carga al menos email o WhatsApp de tu amigo.');
      return;
    }

    Navigator.pop(context, {
      'requesterName': requesterName,
      'name': name,
      'email': email,
      'whatsappE164': whatsappE164,
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amigo responsable')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header motivacional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.handshake_rounded,
                      color: Colors.green.shade700, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tu amigo responsable va a recibir una notificación cada vez que pidas desbloquear una app. '
                      'Su aprobación es necesaria para continuar.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Sección: Tu información
            _buildSectionHeader(
              icon: Icons.person_rounded,
              label: 'Tu información',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: requesterController,
              decoration: const InputDecoration(
                labelText: 'Tu nombre y apellido',
                helperText: 'Así aparecerá en la solicitud que recibe tu amigo.',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 28),

            // Sección: Datos del amigo
            _buildSectionHeader(
              icon: Icons.group_rounded,
              label: 'Datos del amigo',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del amigo',
                helperText: 'Solo para identificarlo en la app.',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email del amigo (opcional)',
                helperText: 'Recibirá el link de aprobación por correo.',
                hintText: 'amigo@ejemplo.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp del amigo (opcional)',
                helperText:
                    'Incluí el código de país. Ej: +5491112345678',
                hintText: '+5491112345678',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveFriend(),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Completá al menos uno: email o WhatsApp.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveFriend,
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Guardar amigo',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.green.shade800,
          ),
        ),
      ],
    );
  }
}
