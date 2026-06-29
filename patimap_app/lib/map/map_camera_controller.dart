import 'package:latlong2/latlong.dart';

/// Harita dışından kamera hareketi (ör. bölge araması) için ince köprü.
/// [RealMapSection] içindeki [MapController] ile ömür boyu eşleştirilir.
final class MapCameraController {
  void Function(LatLng center, double zoom)? _handler;

  void attach(void Function(LatLng center, double zoom) handler) {
    _handler = handler;
  }

  void detach() {
    _handler = null;
  }

  /// Harita henüz bağlı değilse false döner (sessizce yoksayılır).
  bool moveTo(LatLng center, double zoom) {
    final h = _handler;
    if (h == null) return false;
    h(center, zoom);
    return true;
  }
}
