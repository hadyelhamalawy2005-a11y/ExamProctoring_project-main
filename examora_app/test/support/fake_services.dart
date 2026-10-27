import 'dart:async';

import 'package:examora_app/features/proctoring/data/platform_services.dart';
import 'package:examora_app/features/proctoring/domain/capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A camera the test controls. It never opens real hardware.
final class FakeCameraService implements CameraService {
  FakeCameraService([this.result]);

  /// What [start] returns; defaults to a working camera.
  CameraCheck? result;
  int starts = 0;
  int stops = 0;

  @override
  Future<CameraCheck> start() async {
    starts++;
    return result ?? const CameraWorking(SizedBox(key: Key('fake-camera-preview'), height: 40));
  }

  @override
  Future<void> stop() async => stops++;
}

/// A network the test switches on and off.
final class FakeConnectivity implements ConnectivitySource {
  FakeConnectivity({this.online = true});

  bool online;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  void set({required bool value}) {
    online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get changes => _changes.stream;
}

/// A screenshot guard the test can fire.
final class FakeGuard implements PlatformGuard {
  FakeGuard({this.status = const GuardStatus(screenshotsBlocked: true, screenshotsDetected: true)});

  final GuardStatus status;
  bool enabled = false;
  final StreamController<void> _shots = StreamController<void>.broadcast();

  void screenshot() => _shots.add(null);

  @override
  Future<GuardStatus> enable() async {
    enabled = true;
    return status;
  }

  @override
  Future<void> disable() async => enabled = false;

  @override
  Stream<void> get screenshotEvents => _shots.stream;
}

/// The three fakes, and the overrides that put them in the app.
final class FakeDevice {
  FakeDevice({FakeCameraService? camera, FakeConnectivity? connectivity, FakeGuard? guard})
    : camera = camera ?? FakeCameraService(),
      connectivity = connectivity ?? FakeConnectivity(),
      guard = guard ?? FakeGuard();

  final FakeCameraService camera;
  final FakeConnectivity connectivity;
  final FakeGuard guard;

  List<Override> get overrides => [
    cameraServiceProvider.overrideWithValue(camera),
    connectivitySourceProvider.overrideWithValue(connectivity),
    platformGuardProvider.overrideWithValue(guard),
  ];
}
