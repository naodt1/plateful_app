import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

/// Exposes the RevenueCat service singleton.
final revenueCatProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService.instance;
});

/// Live [CustomerInfo] as a stream, driven by the SDK's update listener.
final customerInfoProvider = StreamProvider<CustomerInfo?>((ref) {
  final svc = ref.watch(revenueCatProvider);
  final controller = StreamController<CustomerInfo?>();

  // Emit the current value immediately, then on every change.
  controller.add(svc.customerInfo.value);
  void listener() => controller.add(svc.customerInfo.value);
  svc.customerInfo.addListener(listener);

  ref.onDispose(() {
    svc.customerInfo.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

/// Reactive "is the user Plateful Pro?" — use this anywhere to gate features.
final isProProvider = Provider<bool>((ref) {
  final svc = ref.watch(revenueCatProvider);
  final info = ref.watch(customerInfoProvider).valueOrNull;
  return svc.isProFrom(info);
});
