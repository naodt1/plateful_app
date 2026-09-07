import 'package:flutter/material.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/services/meta_ads_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/airbnb_button.dart';
import '../widgets/google_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  /// Collapsed by default: most users have no code, and an always visible
  /// field on a signup form costs conversions.
  bool _showReferral = false;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  /// Save any entered code before the account is created. _ensureProfile
  /// reads it back the moment the profile document is written.
  Future<void> _stashReferral() async {
    final raw = _referralController.text.trim();
    if (raw.isEmpty) return;
    final ok = await ReferralService.setPending(raw);
    if (ok) {
      Analytics.referralApplied(ReferralService.normalise(raw)!);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _stashReferral();
      Analytics.signUp('email');
      MetaAds.completedRegistration('email');
      await FirebaseService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Account created and signed in — go straight into the app.
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error =
          FirebaseService.authErrorMessage(e) ?? 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _stashReferral();
      Analytics.signUp('google');
      MetaAds.completedRegistration('google');
      await FirebaseService.signInWithGoogle();
      if (mounted) context.go('/home');
    } catch (e) {
      // Show a friendly message; stay silent if the user just cancelled.
      final msg = FirebaseService.authErrorMessage(e);
      if (msg != null) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 36),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create your\naccount',
                              style: AppTextStyles.displayLarge,
                            ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                            const SizedBox(height: 8),
                            Text(
                              'Start saving recipes you love.',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: colors.textSecondary),
                            ).animate().fadeIn(delay: 100.ms),
                            const SizedBox(height: 36),
                            if (_error != null) _ErrorBox(error: _error!),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(Icons.email_outlined,
                                    color: colors.textSecondary),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Enter your email';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ).animate().fadeIn(delay: 150.ms),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Create a password',
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: colors.textSecondary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: colors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Create a password';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 16),
                            _ReferralField(
                              expanded: _showReferral,
                              controller: _referralController,
                              colors: colors,
                              onExpand: () =>
                                  setState(() => _showReferral = true),
                            ).animate().fadeIn(delay: 220.ms),
                            const SizedBox(height: 24),
                            AirbnbButton(
                              label: 'Create Account',
                              onPressed: _submit,
                              isLoading: _isLoading,
                            ).animate().fadeIn(delay: 250.ms),
                            const SizedBox(height: 16),
                            _OrDivider(colors: colors),
                            const SizedBox(height: 16),
                            GoogleButton(onPressed: _googleSignIn)
                                .animate()
                                .fadeIn(delay: 300.ms),
                            const Spacer(),
                            const SizedBox(height: 16),
                            Center(
                              child: GestureDetector(
                                onTap: () => context.pushReplacement('/login'),
                                child: RichText(
                                  text: TextSpan(
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: colors.textSecondary),
                                    children: const [
                                      TextSpan(
                                          text: 'Already have an account? '),
                                      TextSpan(
                                        text: 'Sign In',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: 350.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final AppColorScheme colors;
  const _OrDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary)),
        ),
        Expanded(child: Divider(color: colors.border)),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  const _ErrorBox({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Creator code entry, collapsed to a single line until tapped.
///
/// Most people arrive without a code, so this stays out of the way rather than
/// adding a field everyone has to skip past.
class _ReferralField extends StatelessWidget {
  final bool expanded;
  final TextEditingController controller;
  final AppColorScheme colors;
  final VoidCallback onExpand;

  const _ReferralField({
    required this.expanded,
    required this.controller,
    required this.colors,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return GestureDetector(
        onTap: onExpand,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 15, color: colors.textSecondary),
              const SizedBox(width: 7),
              Text(
                'Have a creator code?',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return TextFormField(
      controller: controller,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'Creator code',
        hintText: 'e.g. JANE',
        prefixIcon: Icon(Icons.card_giftcard_rounded,
            size: 19, color: colors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      // Never block signup on a malformed code: an unusable one is simply
      // ignored rather than standing between the user and their account.
      validator: (_) => null,
    );
  }
}
