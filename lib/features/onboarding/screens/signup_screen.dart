import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/airbnb_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _emailConfirmationSent = false;
  String? _confirmedEmail;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await SupabaseService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted) context.go('/home');
      } else {
        await SupabaseService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted) {
          setState(() {
            _emailConfirmationSent = true;
            _confirmedEmail = _emailController.text.trim();
          });
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _emailConfirmationSent
            ? _buildConfirmationView()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLogin ? 'Welcome\nback!' : 'Create your\naccount',
                  style: AppTextStyles.displayLarge,
                ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in to continue to Plateful.'
                      : 'Start saving recipes you love.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.of(context).textSecondary),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 36),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: AppColors.of(context).textSecondary),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline,
                        color: AppColors.of(context).textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.of(context).textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (!_isLogin && v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),
                AirbnbButton(
                  label: _isLogin ? 'Sign In' : 'Create Account',
                  onPressed: _submit,
                  isLoading: _isLoading,
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or',
                          style: AppTextStyles.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                AirbnbButton(
                  label: 'Continue with Google',
                  onPressed: _googleSignIn,
                  isOutlined: true,
                  icon: Icons.g_mobiledata,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium,
                        children: [
                          TextSpan(
                            text: _isLogin
                                ? "Don't have an account? "
                                : 'Already have an account? ',
                          ),
                          TextSpan(
                            text: _isLogin ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildConfirmationView() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.primary,
              size: 40,
            ),
          ).animate().scale(begin: const Offset(0.6, 0.6), duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          Text(
            'Check your inbox',
            style: AppTextStyles.displayLarge,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),
          Text(
            'We sent a confirmation link to',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.of(context).textSecondary),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 4),
          Text(
            _confirmedEmail ?? '',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).textPrimary,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 12),
          Text(
            'Tap the link in that email to activate your account, then come back and sign in.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.of(context).textSecondary),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 40),
          AirbnbButton(
            label: 'Go to Sign In',
            onPressed: () {
              setState(() {
                _emailConfirmationSent = false;
                _isLogin = true;
                _passwordController.clear();
                _error = null;
              });
            },
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await SupabaseService.signUpWithEmail(
                  _confirmedEmail!,
                  _passwordController.text,
                );
              } catch (_) {}
              if (mounted) setState(() => _isLoading = false);
            },
            child: Text(
              'Resend confirmation email',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}
