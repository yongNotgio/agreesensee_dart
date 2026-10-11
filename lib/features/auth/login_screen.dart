import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../repositories/auth_repository.dart';

/// Email/password sign-in. In demo mode it lists the seeded accounts and
/// accepts any password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
      // Router redirect handles navigation to the correct portal.
    } on AuthFailure catch (e) {
      _showError(e.message);
    } on Object catch (e) {
      _showError('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _fillDemo(String email) {
    _email.text = email;
    _password.text = 'demo1234';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDemo = ref.watch(isDemoModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco,
                          size: 44, color: AppColors.primary),
                    ).withCenter(),
                    const SizedBox(height: 16),
                    Text(AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text('Welcome back',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    const _LoginSaturatedCropsTicker(),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'you@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscure,
                      validator: Validators.password,
                      textInputAction: TextInputAction.done,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        child: Text(_obscure ? 'Show password' : 'Hide password'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?",
                            style: theme.textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => context.push(Routes.register),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                    if (isDemo) _DemoAccountsCard(onPick: _fillDemo),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper card listing the seeded demo accounts.
class _DemoAccountsCard extends StatelessWidget {
  const _DemoAccountsCard({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science, size: 18),
              const SizedBox(width: 6),
              Text('Demo accounts (tap to fill, any password)',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          _DemoTile(
            icon: Icons.agriculture,
            title: 'Juan Dela Cruz — Farmer',
            email: 'farmer@agrisense.ph',
            onTap: () => onPick('farmer@agrisense.ph'),
          ),
          _DemoTile(
            icon: Icons.groups,
            title: 'Maria Santos — Cooperative',
            email: 'coop@agrisense.ph',
            onTap: () => onPick('coop@agrisense.ph'),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.title,
    required this.email,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(email),
      trailing: const Icon(Icons.arrow_forward, size: 16),
      onTap: onTap,
    );
  }
}

extension on Widget {
  Widget withCenter() => Center(child: this);
}

/// Comprehensive Crop Saturation Widget for the Login Screen.
/// Displays an interactive horizontal bar chart and breakdown across all monitored crops
/// so farmers can evaluate market oversupply before logging in.
class _LoginSaturatedCropsTicker extends ConsumerStatefulWidget {
  const _LoginSaturatedCropsTicker();

  @override
  ConsumerState<_LoginSaturatedCropsTicker> createState() =>
      _LoginSaturatedCropsTickerState();
}

class _LoginSaturatedCropsTickerState
    extends ConsumerState<_LoginSaturatedCropsTicker> {
  bool _expanded = false;

  Color _colorFor(SaturationLevel level) => switch (level) {
        SaturationLevel.high => AppColors.riskHigh,
        SaturationLevel.moderate => AppColors.riskModerate,
        SaturationLevel.low => AppColors.riskLow,
      };

  @override
  Widget build(BuildContext context) {
    final saturationAsync = ref.watch(saturationProvider);
    final theme = Theme.of(context);

    return saturationAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();

        final highCount =
            results.where((r) => r.level == SaturationLevel.high).length;
        final moderateCount =
            results.where((r) => r.level == SaturationLevel.moderate).length;

        // Display all crops in descending order of saturation
        final displayResults = results;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highCount > 0
                  ? AppColors.riskHigh.withValues(alpha: 0.35)
                  : theme.colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (Tappable to expand / collapse)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: highCount > 0
                              ? AppColors.riskHigh.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          highCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.bar_chart_rounded,
                          size: 18,
                          color: highCount > 0
                              ? AppColors.riskHigh
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Municipal Crop Saturation Index',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              highCount > 0
                                  ? '$highCount crop(s) oversupplied, $moderateCount near balance'
                                  : 'All crops within normal market demand',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: highCount > 0
                                    ? AppColors.riskHigh
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: highCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'Hide' : 'View chart',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_expanded) ...[
                const Divider(height: 1),
                // Chart View
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Supply vs Demand',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _LegendDot(color: AppColors.riskHigh, label: '>115% High'),
                              _LegendDot(color: AppColors.riskModerate, label: '85-115%'),
                              _LegendDot(color: AppColors.riskLow, label: '<85%'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Constrained scrollable area for all crops
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final r in displayResults)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    r.cropName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (r.level == SaturationLevel.high) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 13,
                                                    color: AppColors.riskHigh,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(r.index * 100).round()}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: _colorFor(r.level),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${r.expectedSupplyTons.toStringAsFixed(1)}t / ${r.demandTons.toStringAsFixed(1)}t)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Progress bar
                                      Stack(
                                        children: [
                                          Container(
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: (r.index / 2.0).clamp(0.02, 1.0),
                                            child: Container(
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: _colorFor(r.level),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Saturation compares municipal standing crop declarations against local market absorption (90-day horizon). Over 115% indicates imminent oversupply risk.',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
