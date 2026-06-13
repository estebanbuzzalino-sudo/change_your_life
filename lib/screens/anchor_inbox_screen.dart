import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _anchorInboxUrl =
    'https://oggqvcjtvfgyagaisvmj.functions.supabase.co/anchor-inbox';
const _anchorApproveUrl =
    'https://oggqvcjtvfgyagaisvmj.functions.supabase.co/anchor-approve';

// ─── Data model ──────────────────────────────────────────────────────────────

class _PendingRequest {
  final String requestId;
  final String packageName;
  final String appName;
  final String requesterName;
  final int minutes;
  final String requestedAt;

  const _PendingRequest({
    required this.requestId,
    required this.packageName,
    required this.appName,
    required this.requesterName,
    required this.minutes,
    required this.requestedAt,
  });

  factory _PendingRequest.fromJson(Map<String, dynamic> j) => _PendingRequest(
        requestId: j['requestId'] as String? ?? '',
        packageName: j['packageName'] as String? ?? '',
        appName: j['appName'] as String? ?? '',
        requesterName: j['requesterName'] as String? ?? 'Alguien',
        minutes: (j['minutes'] as num?)?.toInt() ?? 60,
        requestedAt: j['requestedAt'] as String? ?? '',
      );
}

// ─── AnchorInboxScreen ────────────────────────────────────────────────────────

class AnchorInboxScreen extends StatefulWidget {
  final String? initialEmail;
  const AnchorInboxScreen({super.key, this.initialEmail});

  @override
  State<AnchorInboxScreen> createState() => _AnchorInboxScreenState();
}

class _AnchorInboxScreenState extends State<AnchorInboxScreen> {
  final _emailCtrl = TextEditingController();
  List<_PendingRequest> _requests = [];
  bool _loading = false;
  bool _hasFetched = false;
  String? _errorMsg;
  String? _lastEmail;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailCtrl.text = widget.initialEmail!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRequests());
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Network ──────────────────────────────────────────────────────────────

  Future<void> _fetchRequests() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
      _lastEmail = email;
    });

    try {
      final uri =
          Uri.parse('$_anchorInboxUrl?email=${Uri.encodeQueryComponent(email)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      if (!mounted) return;
      if (json['ok'] == true) {
        final rawList = (json['data']?['requests'] as List<dynamic>?) ?? [];
        setState(() {
          _requests = rawList
              .cast<Map<String, dynamic>>()
              .map(_PendingRequest.fromJson)
              .toList();
          _hasFetched = true;
        });
      } else {
        setState(() {
          _errorMsg = 'No se pudieron cargar las solicitudes.';
          _hasFetched = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Sin conexión. Verificá tu internet.';
        _hasFetched = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(_PendingRequest req) async {
    final duration = await _showDurationPicker(req);
    if (duration == null) return;

    setState(() => _loading = true);

    try {
      final body = <String, dynamic>{
        'requestId': req.requestId,
        'anchorEmail': _lastEmail ?? _emailCtrl.text.trim().toLowerCase(),
        'durationMode': duration.mode,
        'minutes': duration.minutes,
        'days': duration.days,
      };

      final res = await http
          .post(
            Uri.parse(_anchorApproveUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;

      if (json['ok'] == true) {
        setState(() => _requests.removeWhere((r) => r.requestId == req.requestId));
        _showSnack('Desbloqueo aprobado por ${json['data']?['durationLabel'] ?? ''}.');
      } else {
        final code = json['error']?['code'] ?? '';
        if (code == 'ALREADY_APPROVED') {
          setState(() => _requests.removeWhere((r) => r.requestId == req.requestId));
          _showSnack('Esta solicitud ya fue aprobada.');
        } else if (code == 'TOKEN_EXPIRED') {
          setState(() => _requests.removeWhere((r) => r.requestId == req.requestId));
          _showSnack('La solicitud venció. Pedile al usuario que solicite de nuevo.');
        } else {
          _showSnack('Error al aprobar. Intentá de nuevo.');
        }
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Sin conexión. Verificá tu internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  // ── Duration picker dialog ────────────────────────────────────────────────

  Future<_DurationChoice?> _showDurationPicker(_PendingRequest req) async {
    return showDialog<_DurationChoice>(
      context: context,
      builder: (ctx) => _DurationPickerDialog(req: req),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5B3A),
        foregroundColor: Colors.white,
        title: const Text(
          'Solicitudes para aprobar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (_hasFetched && !_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
              onPressed: _fetchRequests,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildEmailBar(),
          if (_loading) const LinearProgressIndicator(color: Color(0xFFFF5B3A)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildEmailBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetchRequests(),
              decoration: InputDecoration(
                hintText: 'Tu email de ancla',
                hintStyle: const TextStyle(color: Color(0xFFBBA99A), fontSize: 14),
                prefixIcon: const Icon(Icons.email_outlined,
                    color: Color(0xFF7A5C50), size: 18),
                filled: true,
                fillColor: const Color(0xFFF5F0EA),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F1410)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _loading ? null : _fetchRequests,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B3A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Buscar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasFetched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Color(0xFFEFDDD0)),
            SizedBox(height: 12),
            Text(
              'Ingresá tu email y buscá\nlas solicitudes pendientes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9A7060), fontSize: 14, height: 1.6),
            ),
          ],
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: Color(0xFFEFDDD0)),
              const SizedBox(height: 12),
              Text(_errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF9A7060), fontSize: 14)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _fetchRequests,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 64, color: Color(0xFF66BB6A)),
            SizedBox(height: 12),
            Text(
              'Todo tranquilo',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F1410)),
            ),
            SizedBox(height: 6),
            Text(
              'No tenés solicitudes pendientes de aprobar.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Color(0xFF7A5C50), fontSize: 13, height: 1.6),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildRequestCard(_requests[i]),
    );
  }

  Widget _buildRequestCard(_PendingRequest req) {
    final requestedAt = _formatDate(req.requestedAt);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.phone_android_rounded,
                  color: Color(0xFFFF5B3A), size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.appName.isNotEmpty ? req.appName : req.packageName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1F1410),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${req.requesterName} · ${req.minutes} min · $requestedAt',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A5C50),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _loading ? null : () => _approve(req),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Aprobar',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$d/$mo ${h}:$m';
    } catch (_) {
      return '';
    }
  }
}

// ─── Duration choice ──────────────────────────────────────────────────────────

class _DurationChoice {
  final String mode;
  final int? minutes;
  final int? days;
  const _DurationChoice({required this.mode, this.minutes, this.days});
}

// ─── Duration picker dialog ───────────────────────────────────────────────────

class _DurationPickerDialog extends StatefulWidget {
  final _PendingRequest req;
  const _DurationPickerDialog({required this.req});

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  String _mode = 'minutes';
  int _minutes = 60;
  int _days = 1;

  static const _minuteOptions = [10, 15, 20, 30, 45, 60];
  static const _dayOptions = [1, 2, 3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aprobar desbloqueo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 2),
          Text(
            widget.req.appName.isNotEmpty
                ? widget.req.appName
                : widget.req.packageName,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A5C50),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Por cuánto tiempo?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF7A5C50))),
            const SizedBox(height: 10),
            _modeRow('minutes', 'Minutos'),
            if (_mode == 'minutes')
              _chipRow(
                _minuteOptions,
                _minutes,
                (v) => setState(() => _minutes = v),
                (v) => '$v min',
              ),
            const SizedBox(height: 6),
            _modeRow('days', 'Días'),
            if (_mode == 'days')
              _chipRow(
                _dayOptions,
                _days,
                (v) => setState(() => _days = v),
                (v) => '$v d',
              ),
            const SizedBox(height: 6),
            _modeRow('permanent', 'Permanente'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF9A7060))),
        ),
        ElevatedButton(
          onPressed: () {
            final choice = _mode == 'minutes'
                ? _DurationChoice(mode: 'minutes', minutes: _minutes)
                : _mode == 'days'
                    ? _DurationChoice(mode: 'days', days: _days)
                    : const _DurationChoice(mode: 'permanent');
            Navigator.pop(context, choice);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Confirmar',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _modeRow(String mode, String label) {
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: mode,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              activeColor: const Color(0xFFFF5B3A),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(label,
                style: TextStyle(
                    fontWeight:
                        _mode == mode ? FontWeight.w700 : FontWeight.w500,
                    color: _mode == mode
                        ? const Color(0xFF1F1410)
                        : const Color(0xFF7A5C50),
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(
    List<int> options,
    int selected,
    ValueChanged<int> onTap,
    String Function(int) label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options.map((v) {
          final isSelected = v == selected;
          return ChoiceChip(
            label: Text(label(v),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF7A5C50))),
            selected: isSelected,
            onSelected: (_) => onTap(v),
            selectedColor: const Color(0xFFFF5B3A),
            backgroundColor: const Color(0xFFF5F0EA),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        }).toList(),
      ),
    );
  }
}
