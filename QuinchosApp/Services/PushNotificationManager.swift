import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var fcmToken: String?
    @Published var permissionGranted = false
    
    private override init() {
        super.init()
    }
    
    // ─── Configurar Firebase ───
    func configure() {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }
    
    // ─── Pedir permiso de notificaciones ───
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
    
    // ─── Registrar token en el backend ───
    func registrarEnBackend() async {
        guard let token = fcmToken,
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
        print("📱 Token FCM registrado en backend")
    }
    
    // ─── Eliminar token al logout ───
    func eliminarDelBackend() async {
        guard let token = fcmToken,
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

// MARK: - Firebase Messaging Delegate

extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("📱 FCM Token: \(token)")
        Task { @MainActor in
            self.fcmToken = token
            await self.registrarEnBackend()
        }
    }
}

// MARK: - UNUserNotificationCenter Delegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Mostrar notificación cuando la app está en primer plano
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
    
    // Manejar tap en notificación
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notificación abierta: \(userInfo)")
        // TODO: Navegar a la pantalla correspondiente según el tipo
        completionHandler()
    }
}
