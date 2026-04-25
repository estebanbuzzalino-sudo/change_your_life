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
  static final RegExp _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa tu nombre y apellido.')),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el nombre del amigo.')),
      );
      return;
    }

    if (whatsappE164.isNotEmpty && !_e164Regex.hasMatch(whatsappE164)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp invalido. Usa formato +5491112345678.'),
        ),
      );
      return;
    }

    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email invalido. Revisa que tenga formato nombre@dominio.com.'),
        ),
      );
      return;
    }

    if (email.isEmpty && whatsappE164.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carga al menos email o WhatsApp.'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'requesterName': requesterName,
      'name': name,
      'email': email,
      'whatsappE164': whatsappE164,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigo responsable'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: requesterController,
              decoration: const InputDecoration(
                labelText: 'Solicitante (tu nombre y apellido)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del amigo',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email del amigo (opcional)',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp del amigo (opcional)',
                hintText: '+5491112345678',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveFriend,
              child: const Text('Guardar amigo'),
            ),
          ],
        ),
      ),
    );
  }
}
