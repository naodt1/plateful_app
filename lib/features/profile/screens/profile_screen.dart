import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart' show AppColors, AppColorScheme;
import '../../../core/theme/app_text_styles.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../subscription/paywall.dart';

final _profileDetailProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) {
  return SupabaseService.getProfile();
});

const _diets = [
  ('None', '🍽️'),
  ('Vegan', '🌱'),
  ('Vegetarian', '🥦'),
  ('Keto', '🥩'),
  ('Paleo', '🦴'),
  ('Gluten-Free', '🌾'),
  ('Halal', '☪️'),
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _updateDiet(String diet) async {
    await SupabaseService.updateProfile({'diet_mode': diet});
    ref.invalidate(_profileDetailProvider);
  }

  void _showDietPicker(String current) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Diet Preference', style: AppTextStyles.headingMedium),
            const SizedBox(height: 4),
            Text('Used to tailor recipes to your needs.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textSecondary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _diets.map((d) {
                final selected = d.$1 == current;
                return GestureDetector(
                  onTap: () {
                    _updateDiet(d.$1);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color:
                              selected ? AppColors.primary : colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.$2, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(d.$1,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : colors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsSheet(),
    );
  }

  // ── Edit Profile ───────────────────────────────────────────────────────────

  void _showEditProfile(String currentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        currentName: currentName,
        onSaved: () => ref.invalidate(_profileDetailProvider),
      ),
    );
  }

  // ── Privacy & Security ─────────────────────────────────────────────────────

  void _showPrivacySecurity() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrivacySecuritySheet(),
    );
  }

  // ── Help & FAQ ─────────────────────────────────────────────────────────────

  void _showHelpFaq() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HelpFaqSheet(),
    );
  }

  // ── Rate Plateful ──────────────────────────────────────────────────────────

  Future<void> _ratePlateful() async {
    // Replace with your actual App Store / Play Store ID when published.
    const appStoreUrl =
        'https://apps.apple.com/app/idYOUR_APP_ID?action=write-review';
    const playStoreUrl =
        'market://details?id=com.plateful.app';

    final uri = Uri.parse(
        Theme.of(context).platform == TargetPlatform.android
            ? playStoreUrl
            : appStoreUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store. Please try again later.')),
      );
    }
  }

  // ── About ──────────────────────────────────────────────────────────────────

  void _showAbout() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 16),
            Text('Plateful',
                style: AppTextStyles.headingLarge
                    .copyWith(color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text('Version 1.0.0 (Build 1)',
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textSecondary)),
            const SizedBox(height: 12),
            Text(
              'Your personal AI-powered recipe and meal-planning companion.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            Divider(color: colors.border),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showLicensePage(
                  context: context,
                  applicationName: 'Plateful',
                  applicationVersion: '1.0.0',
                );
              },
              child: Text('Open-Source Licenses',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Opens RevenueCat's Customer Center — lets the user view their plan,
  /// restore purchases, cancel, request refunds, or change plans, all handled
  /// by the SDK's native UI (configured in the RevenueCat dashboard).
  Future<void> _openCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open subscription manager: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.signOut();
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profileAsync = ref.watch(_profileDetailProvider);
    final user = SupabaseService.currentUser;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.headingMedium),
        automaticallyImplyLeading: false,
        backgroundColor: colors.bg,
      ),
      body: profileAsync.when(
        loading: () => const _ProfileSkeleton(),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: AppTextStyles.bodySmall)),
        data: (profile) {
          final name = profile?['display_name'] as String? ?? 'Chef';
          final email = user?.email ?? '';
          final dietMode = profile?['diet_mode'] as String? ?? 'None';
          final dietEmoji =
              _diets.firstWhere((d) => d.$1 == dietMode, orElse: () => _diets[0]).$2;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTextStyles.headingLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(email,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Subscription banner ─────────────────────────────────
              _ProBanner(
                isPro: isPro,
                colors: colors,
                onUpgrade: () => PlatefulPaywall.forcePresent(context),
                onManage: _openCustomerCenter,
              ),
              const SizedBox(height: 24),

              // ── Preferences ─────────────────────────────────────────
              _SectionTitle('Preferences', colors: colors),
              _Group(
                colors: colors,
                children: [
                  _Row(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Diet Preference',
                    colors: colors,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$dietEmoji  $dietMode',
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right,
                            size: 18, color: colors.textSecondary),
                      ],
                    ),
                    onTap: () => _showDietPicker(dietMode),
                  ),
                  _Divider(colors),
                  _Row(
                    icon: isDark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    label: 'Dark Mode',
                    colors: colors,
                    trailing: Switch(
                      value: isDark,
                      activeColor: AppColors.primary,
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    ),
                    onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                  _Divider(colors),
                  _Row(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: _showNotificationsSheet,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Library ─────────────────────────────────────────────
              _SectionTitle('Library', colors: colors),
              _Group(
                colors: colors,
                children: [
                  _Row(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'My Collections',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: () => context.push('/collections'),
                  ),
                  _Divider(colors),
                  _Row(
                    icon: Icons.bookmark_outline,
                    label: 'Saved Recipes',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: () => context.go('/home'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Account ─────────────────────────────────────────────
              _SectionTitle('Account', colors: colors),
              _Group(
                colors: colors,
                children: [
                  _Row(
                    icon: Icons.person_outline,
                    label: 'Edit Profile',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: () => _showEditProfile(name),
                  ),
                  _Divider(colors),
                  _Row(
                    icon: Icons.lock_outline,
                    label: 'Privacy & Security',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: _showPrivacySecurity,
                  ),
                  _Divider(colors),
                  _Row(
                    icon: Icons.card_membership_outlined,
                    label: 'Manage Subscription',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: _openCustomerCenter,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Support ─────────────────────────────────────────────
              _SectionTitle('Support', colors: colors),
              _Group(
                colors: colors,
                children: [
                  _Row(
                    icon: Icons.help_outline,
                    label: 'Help & FAQ',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: _showHelpFaq,
                  ),
                  _Divider(colors),
                  _Row(
                    icon: Icons.star_outline,
                    label: 'Rate Plateful',
                    colors: colors,
                    trailing: _chevron(colors),
                    onTap: _ratePlateful,
                  ),
                  _Divider(colors),
                  _Row(
                    icon: Icons.info_outline,
                    label: 'About',
                    colors: colors,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('v1.0.0',
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 6),
                        _chevron(colors),
                      ],
                    ),
                    onTap: _showAbout,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Sign out ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _chevron(AppColorScheme colors) =>
      Icon(Icons.chevron_right, size: 18, color: colors.textSecondary);
}

// ══════════════════════════════════════════════════════════════════════════════
// Notifications Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _mealReminders = false;
  bool _weeklyPlan = false;
  bool _newRecipes = false;

  static const _kMealReminders = 'notif_meal_reminders';
  static const _kWeeklyPlan = 'notif_weekly_plan';
  static const _kNewRecipes = 'notif_new_recipes';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _mealReminders = prefs.getBool(_kMealReminders) ?? false;
        _weeklyPlan = prefs.getBool(_kWeeklyPlan) ?? false;
        _newRecipes = prefs.getBool(_kNewRecipes) ?? false;
      });
    }
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Notifications', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          Text('Choose what you want to hear from us.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _NotifTile(
                  icon: Icons.alarm_outlined,
                  title: 'Meal Reminders',
                  subtitle: 'Remind me to log or cook my planned meals',
                  value: _mealReminders,
                  colors: colors,
                  onChanged: (v) {
                    setState(() => _mealReminders = v);
                    _save(_kMealReminders, v);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Divider(height: 1, color: colors.border),
                ),
                _NotifTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Weekly Plan Ready',
                  subtitle: 'Notify me when my weekly meal plan is ready',
                  value: _weeklyPlan,
                  colors: colors,
                  onChanged: (v) {
                    setState(() => _weeklyPlan = v);
                    _save(_kWeeklyPlan, v);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Divider(height: 1, color: colors.border),
                ),
                _NotifTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'New Recipe Ideas',
                  subtitle: 'Get AI-generated recipe suggestions',
                  value: _newRecipes,
                  colors: colors,
                  onChanged: (v) {
                    setState(() => _newRecipes = v);
                    _save(_kNewRecipes, v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColorScheme colors;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit Profile Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final VoidCallback onSaved;

  const _EditProfileSheet({
    required this.currentName,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.updateProfile({'display_name': name});
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Edit Profile', style: AppTextStyles.headingMedium),
            const SizedBox(height: 4),
            Text('Update how your name appears in the app.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textSecondary)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                prefixIcon:
                    const Icon(Icons.person_outline, color: AppColors.primary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Privacy & Security Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _PrivacySecuritySheet extends StatefulWidget {
  const _PrivacySecuritySheet();

  @override
  State<_PrivacySecuritySheet> createState() => _PrivacySecuritySheetState();
}

class _PrivacySecuritySheetState extends State<_PrivacySecuritySheet> {
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = SupabaseService.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '📧 Password reset email sent. Check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _requestAccountDeletion() async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.bg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all associated data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // In production: call a Supabase Edge Function or admin API.
      // For now we sign out and show a message.
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Account deletion requested. Our team will process it within 48 hours.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Privacy & Security', style: AppTextStyles.headingMedium),
            const SizedBox(height: 4),
            Text('Manage your account security and data.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textSecondary)),
            const SizedBox(height: 24),
            // Change password section
            Text('Change Password',
                style: AppTextStyles.labelLarge
                    .copyWith(color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'We\'ll send a password reset link to your email address.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon:
                    const Icon(Icons.email_outlined, color: AppColors.primary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _sending ? null : _sendPasswordReset,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary))
                    : const Icon(Icons.lock_reset_outlined,
                        color: AppColors.primary),
                label: Text('Send Reset Email',
                    style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Divider(color: colors.border),
            const SizedBox(height: 16),
            // Danger zone
            Text('Danger Zone',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.error)),
            const SizedBox(height: 8),
            Text(
              'Permanently delete your Plateful account and all your data.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _requestAccountDeletion,
                icon: const Icon(Icons.delete_forever_outlined,
                    color: AppColors.error),
                label: const Text('Delete My Account',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Help & FAQ Sheet
// ══════════════════════════════════════════════════════════════════════════════

const _faqs = [
  (
    'How do I add a recipe?',
    'Tap the + button on the Home screen or the Recipe tab. You can create a recipe from scratch, paste a URL to import from a website, or share a link directly from your browser.',
  ),
  (
    'How do I use the AI recipe generator?',
    'On the Home screen tap "Generate with AI". Describe the dish, your available ingredients, or any dietary constraints and the AI will produce a full recipe with steps and nutrition info.',
  ),
  (
    'Can I organise my recipes into folders?',
    'Yes! Go to Profile → My Collections to create named collections and drag your favourite recipes into them.',
  ),
  (
    'How does the weekly meal planner work?',
    'Open the Meal Plan tab, select any slot (breakfast, lunch, or dinner for each day) and pick a recipe from your library. The planner saves automatically.',
  ),
  (
    'How do I generate a grocery list?',
    'After building your meal plan, tap the shopping cart button at the top of the Meal Plan screen. Plateful will extract all ingredients and add them to your Grocery list.',
  ),
  (
    'What is Plateful Pro?',
    'Plateful Pro unlocks unlimited AI recipe generation, advanced meal planning, nutrition insights, and priority support. Tap "Upgrade" on the Profile screen to subscribe.',
  ),
  (
    'How do I cancel my subscription?',
    'Go to Profile → Manage Subscription. This opens the RevenueCat Customer Center where you can view, pause, or cancel your plan at any time.',
  ),
  (
    'My data is missing after reinstalling. What happened?',
    'All your recipes, collections, and meal plans are stored in the cloud and linked to your account. Simply sign back in with the same email address to restore everything.',
  ),
];

class _HelpFaqSheet extends StatefulWidget {
  const _HelpFaqSheet();

  @override
  State<_HelpFaqSheet> createState() => _HelpFaqSheetState();
}

class _HelpFaqSheetState extends State<_HelpFaqSheet> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Help & FAQ',
                      style: AppTextStyles.headingMedium),
                  const SizedBox(height: 4),
                  Text('Find answers to common questions.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
                itemCount: _faqs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final (q, a) = _faqs[i];
                  final isOpen = _expanded == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isOpen
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : colors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(
                          () => _expanded = isOpen ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(q,
                                      style: AppTextStyles.labelLarge
                                          .copyWith(
                                              color:
                                                  colors.textPrimary)),
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  turns: isOpen ? 0.5 : 0,
                                  duration: const Duration(
                                      milliseconds: 200),
                                  child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: isOpen
                                          ? AppColors.primary
                                          : colors.textSecondary),
                                ),
                              ],
                            ),
                            if (isOpen) ...
                              [
                                const SizedBox(height: 10),
                                Text(a,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(
                                            color: colors
                                                .textSecondary)),
                              ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section title ──────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  final AppColorScheme colors;
  const _SectionTitle(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ── Grouped card ───────────────────────────────────────────────────────────
class _Group extends StatelessWidget {
  final List<Widget> children;
  final AppColorScheme colors;
  const _Group({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(children: children),
    );
  }
}

// ── Setting row ────────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _Row({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: colors.textPrimary)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppColorScheme colors;
  const _Divider(this.colors);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: colors.border),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Row(
          children: [
            SkeletonLoader(width: 64, height: 64, borderRadius: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 140, height: 22),
                  SizedBox(height: 8),
                  SkeletonText(width: 180),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 28),
        SkeletonLoader(width: double.infinity, height: 150, borderRadius: 16),
        SizedBox(height: 24),
        SkeletonLoader(width: double.infinity, height: 110, borderRadius: 16),
      ],
    );
  }
}

/// Subscription status banner. Shows an "upgrade" CTA for free users and a
/// "Pro member" badge with a manage link for subscribers.
class _ProBanner extends StatelessWidget {
  final bool isPro;
  final AppColorScheme colors;
  final VoidCallback onUpgrade;
  final VoidCallback onManage;

  const _ProBanner({
    required this.isPro,
    required this.colors,
    required this.onUpgrade,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (isPro) {
      return GestureDetector(
        onTap: onManage,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plateful Pro',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: colors.textPrimary)),
                    Text('You have full access. Tap to manage.',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
            ],
          ),
        ),
      );
    }

    // Free user — upgrade CTA.
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upgrade to Plateful Pro',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Unlimited AI recipes, meal plans & more',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
