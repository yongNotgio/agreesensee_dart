import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';
import '../../providers/core_providers.dart';
import '../../repositories/auth_repository.dart';
import 'post_signup_advisory_screen.dart';

/// New-account registration.
///
/// The name is captured in parts (not one "full name" box) so it can be matched
/// against the MAO's RSBSA roster, and farmers supply their RSBSA number and
/// barangay so residency can be **confirmed by a cooperative officer** rather
/// than merely asserted by whoever is filling in the form.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _rsbsa = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  UserRole _role = UserRole.farmer;
  String? _barangay;
  bool _submitting = false;

  bool get _isFarmer => _role == UserRole.farmer;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _contact.dispose();
    _rsbsa.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_barangay == null) {
      _showError('Please select your barangay.');
      return;
    }
    setState(() => _submitting = true);
    try {
      // Attach new members to the pilot cooperative when one exists. Resolving
      // it at runtime keeps this valid in live mode (a real cooperative UUID)
      // and demo mode (the seeded association) alike.
      final coops = await ref.read(cooperativeRepositoryProvider).fetchAll();
      final cooperativeId = coops.isNotEmpty ? coops.first.id : null;
      final barangay = _barangay!;

      await ref.read(authControllerProvider.notifier).signUp(
            email: _email.text.trim(),
            password: _password.text,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            middleName: _middleName.text.trim().isEmpty
                ? null
                : _middleName.text.trim(),
            username: _username.text.trim(),
            role: _role,
            contactNumber: _contact.text.trim(),
            barangay: barangay,
            cooperativeId: cooperativeId,
            rsbsaNumber:
                _rsbsa.text.trim().isEmpty ? null : _rsbsa.text.trim(),
          );

      // Land farmers on advice for their barangay rather than an empty
      // dashboard — the first thing they need is what is worth planting.
      if (mounted && _isFarmer) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PostSignupAdvisoryScreen(barangay: barangay),
          ),
        );
      }
    } on AuthFailure catch (e) {
      _showError(e.message);
    } on Object catch (e) {
      _showError('Registration failed: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
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
                    _RoleSelector(
                      value: _role,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Your name'),
                    AppTextField(
                      label: 'First name',
                      controller: _firstName,
                      prefixIcon: Icons.person_outline,
                      validator: (v) =>
                          Validators.required(v, field: 'First name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Middle name (optional)',
                      controller: _middleName,
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Last name',
                      controller: _lastName,
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) =>
                          Validators.required(v, field: 'Last name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Account details'),
                    AppTextField(
                      label: 'Username',
                      controller: _username,
                      prefixIcon: Icons.alternate_email,
                      hint: 'e.g. juan.delacruz',
                      validator: Validators.username,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Contact number',
                      controller: _contact,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Residency'),
                    AppDropdown<String>(
                      label: 'Barangay',
                      value: _barangay,
                      prefixIcon: Icons.location_on_outlined,
                      items: AppConstants.barangays,
                      itemLabel: (b) => b,
                      validator: (v) =>
                          v == null ? 'Select your barangay' : null,
                      onChanged: (v) => setState(() => _barangay = v),
                    ),
                    if (_isFarmer) ...[
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'RSBSA number',
                        controller: _rsbsa,
                        prefixIcon: Icons.badge_outlined,
                        hint: 'As printed on your RSBSA card',
                        keyboardType: TextInputType.number,
                        validator: (v) => Validators.rsbsa(v),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      const _VerificationNotice(),
                    ],
                    const SizedBox(height: 20),
                    _SectionLabel('Password'),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      validator: Validators.password,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Confirm password',
                      controller: _confirmPassword,
                      prefixIcon: Icons.lock_reset_outlined,
                      obscureText: true,
                      validator: (v) =>
                          Validators.matches(v, _password.text),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('I already have an account'),
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

/// Sets the expectation that residency is confirmed by someone else — the
/// account is usable immediately, but carries an unverified badge until then.
class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 18, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your cooperative or barangay technician will confirm this '
              'number against the municipal registry. You can use AgriSense '
              'right away — your profile shows as verified once confirmed.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented Farmer / Cooperative role selector.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});
  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(UserRole role, IconData icon, String subtitle) {
      final selected = value == role;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(role),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(role.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a…',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            tile(UserRole.farmer, Icons.agriculture, 'Plan crops & track P&L'),
            const SizedBox(width: 12),
            tile(UserRole.cooperative, Icons.groups, 'Monitor member supply'),
          ],
        ),
      ],
    );
  }
}
