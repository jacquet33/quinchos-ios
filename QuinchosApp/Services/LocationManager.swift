import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {
    
    // Estado público
    @Published var userLatitude: Double?
    @Published var userLongitude: Double?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating = false
    @Published var locationError: String?
    @Published var cityName: String?
    
    // Estado derivado
    var hasLocation: Bool { userLatitude != nil && userLongitude != nil }
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
    
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }
    
    // ─── Pedir permiso ───
    func requestPermission() {
        locationError = nil
        manager.requestWhenInUseAuthorization()
    }
    
    // ─── Obtener ubicación actual ───
    func requestLocation() {
        guard isAuthorized else {
            requestPermission()
            return
        }
        isLocating = true
        locationError = nil
        manager.requestLocation()
    }
    
    // ─── Geocodificación inversa ───
    private func reverseGeocode(lat: Double, lng: Double) {
        let location = CLLocation(latitude: lat, longitude: lng)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                if let placemark = placemarks?.first {
                    self?.cityName = placemark.locality ?? placemark.administrativeArea ?? "Tu zona"
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.requestLocation()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.userLatitude = location.coordinate.latitude
            self.userLongitude = location.coordinate.longitude
            self.isLocating = false
            self.reverseGeocode(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLocating = false
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Ubicación denegada. Activala en Ajustes > Privacidad > Localización."
                case .locationUnknown:
                    self.locationError = "No se pudo determinar tu ubicación. Intentá de nuevo."
                default:
                    self.locationError = "Error de ubicación: \(clError.localizedDescription)"
                }
            } else {
                self.locationError = error.localizedDescription
            }
        }
    }
}
