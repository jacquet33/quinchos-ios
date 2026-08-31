import SwiftUI

// MARK: - Seguridad de la cuenta

struct SeguridadCuentaView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = CuentaViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var mostrarCambiarPassword = false
    @State private var mostrarEliminar = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {

                    // ─── Cambiar contraseña ───
                    Button { mostrarCambiarPassword = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.appPrimary).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cambiar contraseña").foregroundColor(.appTextPrimary)
                                Text("Se cerrará la sesión en los otros dispositivos")
                                    .font(.caption2).foregroundColor(.appTextMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.appTextMuted)
                        }
                        .padding(16)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // ─── Eliminar cuenta ───
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zona de riesgo")
                            .font(.caption).fontWeight(.bold).foregroundColor(.appError)

                        Button { mostrarEliminar = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.appError).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Eliminar mi cuenta").foregroundColor(.appError)
                                    Text("Se borran todos tus datos de forma permanente")
                                        .font(.caption2).foregroundColor(.appTextMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.appTextMuted)
                            }
                            .padding(16)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.appError.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Seguridad")
        .sheet(isPresented: $mostrarCambiarPassword) {
            CambiarPasswordView()
        }
        .sheet(isPresented: $mostrarEliminar) {
            EliminarCuentaView()
                .environmentObject(authVM)
        }
    }
}

// MARK: - Cambiar contraseña

struct CambiarPasswordView: View {
    @StateObject private var vm = CuentaViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var actual = ""
    @State private var nueva = ""
    @State private var repetir = ""
    @State private var listo = false

    private var problema: String? {
        if nueva.count > 0 && nueva.count < 6 { return "La contraseña nueva necesita al menos 6 caracteres" }
        if !repetir.isEmpty && nueva != repetir { return "Las contraseñas nuevas no coinciden" }
        return nil
    }

    private var puedeGuardar: Bool {
        !actual.isEmpty && nueva.count >= 6 && nueva == repetir
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Elegí una contraseña que no uses en otro lado")
                            .font(.subheadline).foregroundColor(.appTextSecondary)

                        campoSeguro("Contraseña actual", texto: $actual)
                        campoSeguro("Contraseña nueva", texto: $nueva)
                        campoSeguro("Repetir la nueva", texto: $repetir)

                        if let p = problema {
                            Text(p).font(.caption).foregroundColor(.appError)
                        }
                        if let e = vm.error {
                            Text(e).font(.caption).foregroundColor(.appError)
                        }

                        Button {
                            Task {
                                if await vm.cambiarPassword(actual: actual, nueva: nueva) {
                                    listo = true
                                }
                            }
                        } label: {
                            Group {
                                if vm.cargando { ProgressView().tint(.white) }
                                else { Text("Cambiar contraseña").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(puedeGuardar ? Color.appPrimary : Color.appSurfaceLight)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!puedeGuardar || vm.cargando)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Cambiar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.appTextSecondary)
                }
            }
            .alert("Contraseña actualizada", isPresented: $listo) {
                Button("OK") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func campoSeguro(_ label: String, texto: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
            SecureField("", text: texto)
                .foregroundColor(.appTextPrimary)
                .padding(12).background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Eliminar cuenta

struct EliminarCuentaView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = CuentaViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var password = ""
    @State private var confirmoTexto = ""
    @State private var mostrarConfirmacionFinal = false

    private var puedeEliminar: Bool {
        !password.isEmpty && confirmoTexto.uppercased() == "ELIMINAR"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Advertencia
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.appError)
                                Text("Esto no se puede deshacer")
                                    .font(.headline).foregroundColor(.appError)
                            }

                            Text("Al eliminar tu cuenta se borran de forma permanente:")
                                .font(.subheadline).foregroundColor(.appTextSecondary)

                            VStack(alignment: .leading, spacing: 6) {
                                itemBorrado("Tu perfil y datos personales")
                                itemBorrado("Tus espacios publicados y sus fotos")
                                itemBorrado("El historial de reservas")
                                itemBorrado("Tus reseñas y favoritos")
                            }
                        }
                        .padding(16)
                        .background(Color.appError.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text("Si tenés reservas activas, cancelalas o esperá a que terminen antes de eliminar la cuenta.")
                            .font(.caption).foregroundColor(.appTextMuted)

                        // Confirmación
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tu contraseña").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            SecureField("", text: $password)
                                .foregroundColor(.appTextPrimary)
                                .padding(12).background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Escribí ELIMINAR para confirmar")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                            TextField("ELIMINAR", text: $confirmoTexto)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .foregroundColor(.appTextPrimary)
                                .padding(12).background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let e = vm.error {
                            Text(e).font(.caption).foregroundColor(.appError)
                        }

                        Button {
                            mostrarConfirmacionFinal = true
                        } label: {
                            Group {
                                if vm.cargando { ProgressView().tint(.white) }
                                else { Text("Eliminar mi cuenta").fontWeight(.bold) }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(puedeEliminar ? Color.appError : Color.appSurfaceLight)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!puedeEliminar || vm.cargando)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Eliminar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundColor(.appTextSecondary)
                }
            }
            .alert("¿Eliminar tu cuenta?", isPresented: $mostrarConfirmacionFinal) {
                Button("Volver", role: .cancel) {}
                Button("Sí, eliminar", role: .destructive) {
                    Task {
                        if await vm.eliminarCuenta(password: password) {
                            await authVM.logout()
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Se borrarán todos tus datos y no vas a poder recuperarlos.")
            }
        }
    }

    @ViewBuilder
    private func itemBorrado(_ texto: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption2).foregroundColor(.appError)
            Text(texto).font(.caption).foregroundColor(.appTextSecondary)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class CuentaViewModel: ObservableObject {
    @Published var cargando = false
    @Published var error: String?

    func cambiarPassword(actual: String, nueva: String) async -> Bool {
        cargando = true
        error = nil
        defer { cargando = false }

        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/auth/cambiar-password") else {
            error = "No se pudo conectar"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "passwordActual": actual,
            "passwordNueva": nueva,
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            error = "No se pudo conectar con el servidor"
            return false
        }

        if http.statusCode < 400 { return true }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            error = json["error"] as? String ?? "No se pudo cambiar la contraseña"
        }
        return false
    }

    func eliminarCuenta(password: String) async -> Bool {
        cargando = true
        error = nil
        defer { cargando = false }

        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/auth/cuenta") else {
            error = "No se pudo conectar"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["password": password])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            error = "No se pudo conectar con el servidor"
            return false
        }

        if http.statusCode < 400 { return true }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            error = json["error"] as? String ?? "No se pudo eliminar la cuenta"
        }
        return false
    }
}
