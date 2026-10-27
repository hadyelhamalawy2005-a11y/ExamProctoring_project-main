import 'dart:async';

import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:examora_app/features/proctoring/domain/capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The outcome of looking for a camera.
sealed class CameraCheck {
  const CameraCheck();
}

/// A camera is working. [preview] draws what it sees (never recorded).
final class CameraWorking extends CameraCheck {
  /// Creates the result.
  const CameraWorking(this.preview);

  /// The live picture.
  final Widget preview;
}

/// The device has no camera.
final class CameraMissing extends CameraCheck {
  /// Creates the result.
  const CameraMissing();
}

/// The student did not allow camera access.
final class CameraDenied extends CameraCheck {
  /// Creates the result.
  const CameraDenied();
}

/// The camera exists but could not be started.
final class CameraFailed extends CameraCheck {
  /// Creates the result.
  const CameraFailed();
}

/// Looks at the camera for the system check. It only previews: nothing is recorded, saved or sent.
abstract interface class CameraService {
  /// Starts the camera and reports honestly what happened.
  Future<CameraCheck> start();

  /// Releases the camera.
  Future<void> stop();
}

/// The real camera, through the `camera` plugin.
final class DeviceCameraService implements CameraService {
  /// Creates the service.
  DeviceCameraService();

  CameraController? _controller;

  @override
  Future<CameraCheck> start() async {
    await stop();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return const CameraMissing();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final controller = CameraController(
        front.isEmpty ? cameras.first : front.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      return CameraWorking(CameraPreview(controller));
    } on CameraException catch (error) {
      return error.code.toLowerCase().contains('denied') || error.code.toLowerCase().contains('permission')
          ? const CameraDenied()
          : const CameraFailed();
    } on Object {
      return const CameraFailed();
    }
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

/// The real network state, through `connectivity_plus`.
final class DeviceConnectivitySource implements ConnectivitySource {
  /// Creates the source.
  const DeviceConnectivitySource();

  static bool _online(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await Connectivity().checkConnectivity());
    } on Object {
      return true;
    }
  }

  @override
  Stream<bool> get changes => Connectivity().onConnectivityChanged.map(_online);
}

/// The Android guard: FLAG_SECURE blocks screenshots and recordings of the exam screen. It talks to a few lines of Kotlin in
/// `MainActivity`. On any platform without that code (web, desktop, iOS in this build) the call fails and the guard reports
/// that nothing is protected, rather than claiming it is.
final class MethodChannelPlatformGuard implements PlatformGuard {
  /// Creates the guard.
  MethodChannelPlatformGuard();

  static const MethodChannel _channel = MethodChannel('app.examora/secure');
  final StreamController<void> _screenshots = StreamController<void>.broadcast();

  @override
  Future<GuardStatus> enable() async {
    if (kIsWeb) return GuardStatus.none;
    try {
      final blocked = await _channel.invokeMethod<bool>('enable') ?? false;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'screenshot') _screenshots.add(null);
      });
      return GuardStatus(screenshotsBlocked: blocked, screenshotsDetected: false);
    } on MissingPluginException {
      return GuardStatus.none;
    } on PlatformException {
      return GuardStatus.none;
    }
  }

  @override
  Future<void> disable() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } on MissingPluginException {
      // Nothing was enabled.
    } on PlatformException {
      // Nothing to undo.
    }
  }

  @override
  Stream<void> get screenshotEvents => _screenshots.stream;
}

/// The camera the app uses. Tests replace it.
final cameraServiceProvider = Provider<CameraService>((ref) => DeviceCameraService());

/// The network source the app uses. Tests replace it.
final connectivitySourceProvider = Provider<ConnectivitySource>((ref) => const DeviceConnectivitySource());

/// The screenshot guard the app uses. Tests replace it.
final platformGuardProvider = Provider<PlatformGuard>((ref) => MethodChannelPlatformGuard());

/// The face, gaze and speech detectors: none exist, so this is the null suite.
final detectorSuiteProvider = Provider<DetectorSuite>((ref) => const NullDetectorSuite());

/// The retrospective video buffer: unavailable.
final evidenceBufferProvider = Provider<EvidenceBuffer>((ref) => const UnavailableEvidenceBuffer());
