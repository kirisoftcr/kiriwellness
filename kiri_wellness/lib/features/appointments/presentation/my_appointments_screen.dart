// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/calendar_helper.dart';
import '../../../shared/models/appointment_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { email, otp, appointments, tokenLoading }

class _MyAppointmentsState {
  final _Phase phase;
  final String email;
  final String clientId;
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> packages;

  const _MyAppointmentsState({
    this.phase = _Phase.email,
    this.email = '',
    this.clientId = '',
    this.loading = false,
    this.error,
    this.appointments = const [],
    this.packages = const [],
  });

  _MyAppointmentsState copyWith({
    _Phase? phase,
    String? email,
    String? clientId,
    bool? loading,
    String? error,
    List<Map<String, dynamic>>? appointments,
    List<Map<String, dynamic>>? packages,
    bool clearError = false,
  }) =>
      _MyAppointmentsState(
        phase: phase ?? this.phase,
        email: email ?? this.email,
        clientId: clientId ?? this.clientId,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        appointments: appointments ?? this.appointments,
        packages: packages ?? this.packages,
      );
}

class _MyAppointmentsNotifier extends StateNotifier<_MyAppointmentsState> {
  _MyAppointmentsNotifier() : super(const _MyAppointmentsState());

  Future<void> loadByToken(String token) async {
    state = state.copyWith(loading: true, phase: _Phase.tokenLoading, clearError: true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('getAppointmentsByToken');
      final result = await callable.call<Map<String, dynamic>>({'token': token});
      final data = result.data;
      final rawList = data['appointments'] as List? ?? [];
      final apts = rawList.cast<Map<String, dynamic>>();
      final clientId = data['clientId'] as String? ?? '';

      // Also load packages in parallel
      List<Map<String, dynamic>> pkgs = [];
      try {
        pkgs = await _fetchPackages(token: token);
      } catch (_) {}

      state = state.copyWith(
          loading: false,
          phase: _Phase.appointments,
          email: data['email'] as String? ?? '',
          clientId: clientId,
          appointments: apts,
          packages: pkgs);
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
          loading: false, phase: _Phase.email, error: e.message);
    } catch (e) {
      state = state.copyWith(
          loading: false, phase: _Phase.email, error: e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPackages({String? token, String? clientId}) async {
    final callable = FirebaseFunctions.instanceFor(region: "us-central1")
        .httpsCallable('getClientPackages');
    final payload = token != null ? {'token': token} : {'clientId': clientId};
    final result = await callable.call<Map<String, dynamic>>(payload);
    final raw = result.data['packages'] as List? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<void> sendCode(String email) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "us-central1").httpsCallable('sendVerificationCode');
      await callable.call({'email': email});
      state = state.copyWith(
          loading: false, phase: _Phase.otp, email: email);
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> verifyCode(String code) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "us-central1").httpsCallable('verifyClientCode');
      final result = await callable
          .call<Map<String, dynamic>>({'email': state.email, 'code': code});
      final data = result.data;
      final rawList = data['appointments'] as List? ?? [];
      final apts = rawList.cast<Map<String, dynamic>>();
      final clientId = data['clientId'] as String? ?? '';

      List<Map<String, dynamic>> pkgs = [];
      try {
        pkgs = await _fetchPackages(clientId: clientId);
      } catch (_) {}

      state = state.copyWith(
          loading: false,
          phase: _Phase.appointments,
          clientId: clientId,
          appointments: apts,
          packages: pkgs);
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> cancelAppointment(String appointmentId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('cancelAppointmentByClient');
      await callable.call(
          {'clientId': state.clientId, 'appointmentId': appointmentId});
      final updated = state.appointments.map((a) {
        if (a['id'] == appointmentId) return {...a, 'status': 'cancelled'};
        return a;
      }).toList();
      state = state.copyWith(loading: false, appointments: updated);
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> confirmAppointment(String appointmentId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: "us-central1")
          .httpsCallable('confirmAppointmentByClient');
      await callable.call(
          {'clientId': state.clientId, 'appointmentId': appointmentId});
      final updated = state.appointments.map((a) {
        if (a['id'] == appointmentId) return {...a, 'status': 'confirmed'};
        return a;
      }).toList();
      state = state.copyWith(loading: false, appointments: updated);
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void back() {
    if (state.phase == _Phase.otp) {
      state = state.copyWith(phase: _Phase.email, clearError: true);
    }
  }
}

final _myAptProvider =
    StateNotifierProvider.autoDispose<_MyAppointmentsNotifier, _MyAppointmentsState>(
        (_) => _MyAppointmentsNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MyAppointmentsScreen extends ConsumerStatefulWidget {
  final String? token;
  const MyAppointmentsScreen({super.key, this.token});

  @override
  ConsumerState<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    // Prefer token passed via GoRouter, fallback to reading directly from the
    // browser URL (handles cases where GoRouter drops query params from hash)
    final token = widget.token?.isNotEmpty == true
        ? widget.token!
        : _tokenFromBrowserUrl();
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_myAptProvider.notifier).loadByToken(token);
      });
    }
  }

  String? _tokenFromBrowserUrl() {
    if (!kIsWeb) return null;
    try {
      final uri = Uri.base;
      // Try query params on the full URL first: ?token=xxx
      if (uri.queryParameters.containsKey('token')) {
        return uri.queryParameters['token'];
      }
      // Fallback: parse query string embedded inside the hash fragment
      // e.g. /#/my-appointments?token=xxx
      final fragment = uri.fragment; // "/my-appointments?token=xxx"
      final qIndex = fragment.indexOf('?');
      if (qIndex != -1) {
        final queryString = fragment.substring(qIndex + 1);
        final params = Uri.splitQueryString(queryString);
        return params['token'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_myAptProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Mis Citas',
            style: TextStyle(
                color: AppTheme.primaryDark, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppTheme.primary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (s.phase) {
              _Phase.email => _EmailPhase(state: s),
              _Phase.otp => _OtpPhase(state: s),
              _Phase.tokenLoading => const _TokenLoadingPhase(),
              _Phase.appointments => _AppointmentsList(state: s),
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: Token loading (auto-auth from email link)
// ─────────────────────────────────────────────────────────────────────────────

class _TokenLoadingPhase extends StatelessWidget {
  const _TokenLoadingPhase();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 24),
          Text('Cargando tus citas...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: Email input
// ─────────────────────────────────────────────────────────────────────────────

class _EmailPhase extends ConsumerStatefulWidget {
  final _MyAppointmentsState state;
  const _EmailPhase({required this.state});

  @override
  ConsumerState<_EmailPhase> createState() => _EmailPhaseState();
}

class _EmailPhaseState extends ConsumerState<_EmailPhase> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.email);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(_myAptProvider.notifier);
    final loading = widget.state.loading;
    final error = widget.state.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.calendar_month_outlined,
            size: 56, color: AppTheme.primary),
        const SizedBox(height: 20),
        Text('Ver mis citas',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryDark, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu correo para recibir un código de verificación.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: _inputDec(
              label: 'Correo electrónico', hint: 'tu@correo.com', icon: Icons.email_outlined),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: loading
              ? null
              : () {
                  final email = _ctrl.text.trim();
                  if (email.isNotEmpty && email.contains('@')) {
                    notifier.sendCode(email);
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enviar código'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: OTP input
// ─────────────────────────────────────────────────────────────────────────────

class _OtpPhase extends ConsumerStatefulWidget {
  final _MyAppointmentsState state;
  const _OtpPhase({required this.state});

  @override
  ConsumerState<_OtpPhase> createState() => _OtpPhaseState();
}

class _OtpPhaseState extends ConsumerState<_OtpPhase> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(_myAptProvider.notifier);
    final loading = widget.state.loading;
    final error = widget.state.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.mark_email_read_outlined,
            size: 56, color: AppTheme.primary),
        const SizedBox(height: 20),
        Text('Código enviado',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryDark, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            children: [
              const TextSpan(text: 'Enviamos un código de 6 dígitos a '),
              TextSpan(
                  text: widget.state.email,
                  style: const TextStyle(
                      color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: _inputDec(label: 'Código', hint: '123456', icon: Icons.pin_outlined),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading
              ? null
              : () {
                  final code = _ctrl.text.trim();
                  if (code.length == 6) notifier.verifyCode(code);
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Verificar'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: notifier.back,
          child: const Text('Cambiar correo',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase: Appointments list
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentsList extends ConsumerWidget {
  final _MyAppointmentsState state;
  const _AppointmentsList({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(_myAptProvider.notifier);
    final apts = state.appointments;
    final packages = state.packages;

    // Sort: active first, then cancelled/completed
    final active = apts
        .where((a) => a['status'] == 'requested' || a['status'] == 'confirmed')
        .toList();
    final past = apts
        .where((a) => a['status'] == 'cancelled' || a['status'] == 'completed')
        .toList();

    final activePackages =
        packages.where((p) => p['status'] == 'active').toList();
    final inactivePackages =
        packages.where((p) => p['status'] != 'active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('Tus citas',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryDark, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${apts.length} cita${apts.length == 1 ? '' : 's'} encontrada${apts.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Text(state.error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        // ── New appointment button ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              if (kIsWeb) {
                html.window.location.href = '/#/book';
              }
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Agendar nueva cita'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // ── Packages section ───────────────────────────────────────────────
        if (packages.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('Mis paquetes',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${packages.length} paquete${packages.length == 1 ? '' : 's'} asignado${packages.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          if (activePackages.isNotEmpty) ...[
            const _SectionLabel('Activos'),
            const SizedBox(height: 8),
            ...activePackages.map((p) => _PackageProgressCard(pkg: p)),
          ],
          if (inactivePackages.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Completados / Expirados'),
            const SizedBox(height: 8),
            ...inactivePackages.map((p) => _PackageProgressCard(pkg: p)),
          ],
        ],

        const SizedBox(height: 24),
        if (apts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined,
                      size: 48, color: AppTheme.primaryLight),
                  SizedBox(height: 12),
                  Text('No tienes citas registradas.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          )
        else ...[
          if (active.isNotEmpty) ...[
            const _SectionLabel('Próximas'),
            const SizedBox(height: 8),
            ...active.map((a) => _AptCard(
                  apt: a,
                  onCancel: () => notifier.cancelAppointment(a['id'] as String),
                  onConfirm: (a['status'] as String?) == 'requested'
                      ? () => notifier.confirmAppointment(a['id'] as String)
                      : null,
                  actioning: state.loading,
                )),
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Historial'),
            const SizedBox(height: 8),
            ...past.map((a) => _AptCard(apt: a)),
          ],
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package Progress Card (client portal)
// ─────────────────────────────────────────────────────────────────────────────

class _PackageProgressCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  const _PackageProgressCard({required this.pkg});

  @override
  Widget build(BuildContext context) {
    final name = pkg['packageName'] as String? ?? '';
    final description = pkg['packageDescription'] as String? ?? '';
    final status = pkg['status'] as String? ?? 'active';
    final rawServices = pkg['services'] as List<dynamic>? ?? [];
    final expiresAt = pkg['expiresAt'] as String? ?? '';

    String expiresLabel = '';
    try {
      final d = DateTime.parse(expiresAt).toLocal();
      expiresLabel = 'Vence ${d.day}/${d.month}/${d.year}';
    } catch (_) {}

    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppTheme.primaryLight : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_outlined,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
              ),
              _PkgStatusBadge(status),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
          if (expiresLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(expiresLabel,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ],
          const SizedBox(height: 12),
          ...rawServices.map((sRaw) {
            final s = sRaw as Map<String, dynamic>;
            final sName = s['serviceName'] as String? ?? '';
            final total = (s['totalSessions'] as num?)?.toInt() ?? 0;
            final used = (s['usedSessions'] as num?)?.toInt() ?? 0;
            final remaining = total - used;
            final progress = total > 0 ? used / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(sName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary)),
                      ),
                      Text('$used/$total sesiones',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          AppTheme.primaryLight.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary),
                    ),
                  ),
                  if (isActive && remaining > 0) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (kIsWeb) {
                            html.window.location.href = '/#/book';
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 14),
                        label: Text(
                            'Agendar ($remaining disponible${remaining == 1 ? '' : 's'})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PkgStatusBadge extends StatelessWidget {
  final String status;
  const _PkgStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'active' => (
          'Activo',
          AppTheme.primary,
          AppTheme.primaryLight.withValues(alpha: 0.3)
        ),
      'completed' => (
          'Completado',
          AppTheme.textSecondary,
          const Color(0xFFF5F5F5)
        ),
      'expired' => ('Expirado', AppTheme.error, const Color(0xFFFFEBEE)),
      _ => (
          'Activo',
          AppTheme.primary,
          AppTheme.primaryLight.withValues(alpha: 0.3)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _AptCard extends StatelessWidget {
  final Map<String, dynamic> apt;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool actioning;

  const _AptCard({
    required this.apt,
    this.onCancel,
    this.onConfirm,
    this.actioning = false,
  });

  String _formatAmPm(String time24) {
    try {
      final parts = time24.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return time24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = AppointmentStatusX.fromString(apt['status'] as String?);
    final isCancellable =
        status == AppointmentStatus.requested || status == AppointmentStatus.confirmed;
    final isConfirmable = status == AppointmentStatus.requested;
    final date = apt['date'] as String? ?? '';
    final time = apt['time'] as String? ?? '';

    // Parse date for display
    String dateLabel = date;
    try {
      final d = DateFormat('yyyy-MM-dd').parse(date);
      dateLabel = DateFormat('EEEE d \'de\' MMMM yyyy', 'es').format(d);
      dateLabel = dateLabel[0].toUpperCase() + dateLabel.substring(1);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCancellable
              ? AppTheme.primaryLight
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  apt['serviceName'] as String? ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
              ),
              _StatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(Icons.calendar_today_outlined, dateLabel),
          const SizedBox(height: 4),
          _InfoRow(Icons.schedule, _formatAmPm(time)),
          if (status == AppointmentStatus.confirmed ||
              status == AppointmentStatus.requested) ...[  
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => showAddToCalendar(
                context,
                id: apt['id'] as String? ?? '',
                serviceName: apt['serviceName'] as String? ?? '',
                date: date,
                time: time,
                durationMin: (apt['serviceDurationMin'] as num?)?.toInt() ?? 60,
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text('Agregar al calendario'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontSize: 13),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          if (isCancellable) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isConfirmable && onConfirm != null) ...[  
                  FilledButton.icon(
                    onPressed: actioning ? null : onConfirm,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Confirmar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: actioning ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancelar cita'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AppointmentStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      AppointmentStatus.requested => (AppTheme.primary, AppTheme.primaryLight.withValues(alpha: 0.3)),
      AppointmentStatus.confirmed => (const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      AppointmentStatus.cancelled => (AppTheme.error, const Color(0xFFFFEBEE)),
      AppointmentStatus.completed => (AppTheme.textSecondary, const Color(0xFFF5F5F5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared input decoration helper (file-level)
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDec({
  required String label,
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
    filled: true,
    fillColor: AppTheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
    ),
    labelStyle: const TextStyle(color: AppTheme.textSecondary),
  );
}
