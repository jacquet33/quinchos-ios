import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var deviceToken: String?
    @Published var permissionGranted = false
    
    private override init() { super.init() }
    
    // Configurar (sin Firebase)
    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Pedir permiso
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            Task { @MainActor in
                self.permissionGranted = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // Recibir token APNs del sistema
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs Token: \(token)")
        self.deviceToken = token
        Task { await registrarEnBackend() }
    }
    
    // Registrar en backend
    func registrarEnBackend() async {
        guard let token = deviceToken,
              let authToken = await APIService.shared.getToken() else { return }
        
        guard let url = URL(string: "\(APIConfig.baseURL)/dispositivos/registrar") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,
            "plataforma": "ios"
        ])
        _ = try? await URLSession.shared.data(for: request)
        print("📱 Token registrado en backend")
    }
    
    // Eliminar al logout
    func eliminarDelBackend() async {
        guard let token = deviceToken,
              let authToken = await APIService.shared.getToken() else { return }
        
        guard let url = URL(string: "\(APIConfig.baseURL)/dispositivos/eliminar") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])
        _ = try? await URLSession.shared.data(for: request)
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📱 Notificación abierta: \(response.notification.request.content.userInfo)")
        completionHandler()
    }
}
