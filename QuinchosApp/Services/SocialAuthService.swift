import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Configuración

enum SocialConfig {
    /// Client ID de tipo "iOS" de Google Cloud Console
    static let googleClientID = "640270129167-k2u215i6t80f29ioo4g1l88339b751k2.apps.googleusercontent.com"

    /// Se arma dando vuelta el client ID, es el esquema que registra la app
    static var googleRedirectScheme: String {
        let sinSufijo = googleClientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(sinSufijo)"
    }

    static var googleRedirectURI: String { "\(googleRedirectScheme):/oauth2redirect" }

    static var googleConfigurado: Bool { !googleClientID.hasPrefix("TU_CLIENT_ID") }
}

// MARK: - Servicio de login social

@MainActor
final class SocialAuthService: NSObject, ObservableObject {
    @Published var cargando = false
    @Published var error: String?

    private var continuacionApple: CheckedContinuation<ASAuthorization, Error>?
    private var sesionWeb: ASWebAuthenticationSession?

    // ═══════════════════════════════
    // APPLE (nativo, sin dependencias)
    // ═══════════════════════════════

    func entrarConApple() async -> AuthResponse? {
        cargando = true
        error = nil
        defer { cargando = false }

        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let autorizacion: ASAuthorization = try await withCheckedThrowingContinuation { cont in
                self.continuacionApple = cont
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }

            guard let credencial = autorizacion.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credencial.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                error = "No pudimos leer los datos de tu cuenta de Apple"
                return nil
            }

            // Apple manda el nombre solo la primera vez
            let nombre = [credencial.fullName?.givenName, credencial.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            return await enviarAlBackend(
                path: "/auth/apple",
                cuerpo: [
                    "identityToken": identityToken,
                    "nombre": nombre.isEmpty ? NSNull() : nombre,
                ]
            )
        } catch let err as ASAuthorizationError where err.code == .canceled {
            return nil // el usuario canceló, no es un error
        } catch {
            self.error = "No se pudo completar el inicio de sesión con Apple"
            return nil
        }
    }

    // ═══════════════════════════════
    // GOOGLE (OAuth por web, sin SDK)
    // ═══════════════════════════════

    func entrarConGoogle() async -> AuthResponse? {
        guard SocialConfig.googleConfigurado else {
            error = "Google todavía no está configurado"
            return nil
        }

        cargando = true
        error = nil
        defer { cargando = false }

        // PKCE: protege el intercambio de código sin necesitar secreto de cliente
        let verificador = generarVerificadorPKCE()
        let desafio = generarDesafioPKCE(verificador)

        var componentes = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        componentes.queryItems = [
            .init(name: "client_id", value: SocialConfig.googleClientID),
            .init(name: "redirect_uri", value: SocialConfig.googleRedirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: desafio),
            .init(name: "code_challenge_method", value: "S256"),
        ]

        guard let urlAuth = componentes.url else { return nil }

        // Abrir el navegador seguro del sistema
        let urlRespuesta: URL
        do {
            urlRespuesta = try await withCheckedThrowingContinuation { cont in
                let sesion = ASWebAuthenticationSession(
                    url: urlAuth,
                    callbackURLScheme: SocialConfig.googleRedirectScheme
                ) { url, err in
                    if let url { cont.resume(returning: url) }
                    else { cont.resume(throwing: err ?? URLError(.cancelled)) }
                }
                sesion.presentationContextProvider = self
                sesion.prefersEphemeralWebBrowserSession = false
                self.sesionWeb = sesion
                sesion.start()
            }
        } catch {
            return nil // canceló
        }

        // Sacar el código de la URL de vuelta
        guard let code = URLComponents(url: urlRespuesta, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            self.error = "No recibimos la autorización de Google"
            return nil
        }

        // Canjear el código por el id_token
        guard let idToken = await canjearCodigoGoogle(code: code, verificador: verificador) else {
            self.error = "No se pudo completar el inicio de sesión con Google"
            return nil
        }

        return await enviarAlBackend(path: "/auth/google", cuerpo: ["idToken": idToken])
    }

    private func canjearCodigoGoogle(code: String, verificador: String) async -> String? {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parametros = [
            "client_id": SocialConfig.googleClientID,
            "code": code,
            "code_verifier": verificador,
            "grant_type": "authorization_code",
            "redirect_uri": SocialConfig.googleRedirectURI,
        ]
        request.httpBody = parametros
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["id_token"] as? String
    }

    // ═══════════════════════════════
    // PKCE
    // ═══════════════════════════════

    private func generarVerificadorPKCE() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generarDesafioPKCE(_ verificador: String) -> String {
        let hash = SHA256.hash(data: Data(verificador.utf8))
        return Data(hash).base64URLEncoded()
    }

    // ═══════════════════════════════
    // Backend
    // ═══════════════════════════════

    private func enviarAlBackend(path: String, cuerpo: [String: Any]) async -> AuthResponse? {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: cuerpo)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            error = "No se pudo conectar con el servidor"
            return nil
        }

        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                error = json["error"] as? String ?? "No se pudo iniciar sesión"
            }
            return nil
        }

        guard let respuesta = try? JSONDecoder().decode(AuthResponse.self, from: data) else {
            error = "Respuesta inesperada del servidor"
            return nil
        }

        await APIService.shared.setToken(respuesta.token)
        return respuesta
    }
}

// MARK: - Delegates

extension SocialAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            continuacionApple?.resume(returning: authorization)
            continuacionApple = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            continuacionApple?.resume(throwing: error)
            continuacionApple = nil
        }
    }
}

extension SocialAuthService: ASWebAuthenticationPresentationContextProviding,
                             ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ventanaActiva()
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        ventanaActiva()
    }

    nonisolated private func ventanaActiva() -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Base64 URL-safe

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
