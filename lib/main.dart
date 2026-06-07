import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env may not exist in production; use dart-define instead
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://placeholder.supabase.co');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'placeholder-key');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Configure RevenueCat, then tie purchases to the signed-in account.
  await RevenueCatService.instance.configure();
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    await RevenueCatService.instance.identify(currentUser.id);
  }
  // Keep RevenueCat's user in sync with Supabase auth changes.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final user = data.session?.user;
    if (user != null) {
      RevenueCatService.instance.identify(user.id);
    } else {
      RevenueCatService.instance.logOut();
    }
  });

  runApp(
    const ProviderScope(
      child: PlatefulApp(),
    ),
  );
}
