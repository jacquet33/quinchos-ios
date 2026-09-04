import SwiftUI
import UIKit

// MARK: - Detalle de Reserva (propietario y usuario)

struct ReservaDetalleView: View {
    let reserva: Reserva
    let esPropietario: Bool
    var onActualizar: (() -> Void)? = nil
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = ReservaDetalleViewModel()
    @State private var showCancelar = false
    @State private var showRechazar = false
    @State private var motivoTexto = ""
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // ─── Estado ───
                    HStack {
                        EstadoBadge(estado: vm.estadoActual ?? reserva.estado)
                        Spacer()
                        Text("#\(reserva.id.suffix(6).uppercased())")
                            .font(.caption).foregroundColor(.appTextMuted)
                    }
                    
                    // ─── Quincho ───
                    if let q = reserva.quincho {
                        HStack(spacing: 12) {
                            ImagenRemota(url: q.imagenes?.first?.url, usarMiniatura: true)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.nombre).font(.headline).foregroundColor(.appTextPrimary)
                                Text(q.tipo.label).font(.caption).foregroundColor(.appPrimary)
                                HStack(spacing: 4) {
                                    Image(systemName: "location").font(.system(size: 9))
                                    Text(q.direccion).font(.caption).lineLimit(1)
                                }
                                .foregroundColor(.appTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // ─── Datos de la reserva ───
                    SeccionTitulo("Datos de la reserva")
                    VStack(spacing: 0) {
                        DetalleFila(icono: "calendar", label: "Fecha", valor: formatearFecha(reserva.fecha))
                        DetalleFila(icono: "clock", label: "Horario", valor: "\(reserva.horaInicio) – \(reserva.horaFin)")
                        DetalleFila(icono: "person.2", label: "Personas", valor: "\(reserva.cantidadPersonas)")
                        DetalleFila(icono: "dollarsign.circle", label: "Total", valor: reserva.precioTotal.formattedPrecio, destacado: true)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // ─── Notas ───
                    if let notas = reserva.notas, !notas.isEmpty {
                        SeccionTitulo("Notas del cliente")
                        Text(notas)
                            .font(.subheadline).foregroundColor(.appTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // ─── Contacto ───
                    if esPropietario, let u = reserva.usuario {
                        SeccionTitulo("Cliente")
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Circle().fill(Color.appSurfaceLight).frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "person").foregroundColor(.appTextMuted))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.nombre).font(.subheadline).fontWeight(.semibold).foregroundColor(.appTextPrimary)
                                    if let email = u.email {
                                        Text(email).font(.caption).foregroundColor(.appTextSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(14)
                            
                            if let tel = u.telefono, !tel.isEmpty {
                                Divider().background(Color.appBorder)
                                HStack(spacing: 12) {
                                    Button {
                                        abrirWhatsApp(telefono: tel, nombre: reserva.quincho?.nombre ?? "")
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "message.fill")
                                            Text("WhatsApp")
                                        }
                                        .font(.caption).fontWeight(.semibold).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(Color.appSuccess)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Button {
                                        if let url = URL(string: "tel://\(tel.filter { $0.isNumber })") {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "phone.fill")
                                            Text("Llamar")
                                        }
                                        .font(.caption).fontWeight(.semibold).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(Color.appPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(14)
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // ─── Motivo de cancelación ───
                    if let motivo = vm.motivoCancelacion ?? reserva.motivoCancelacion, !motivo.isEmpty {
                        SeccionTitulo("Motivo")
                        Text(motivo)
                            .font(.subheadline).foregroundColor(.appError)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.appError.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    if let error = vm.error {
                        Text(error).font(.caption).foregroundColor(.appError)
                    }
                    
                    // ─── Invitaciones ───
                    let estadoActual = vm.estadoActual ?? reserva.estado
                    if !esPropietario && (estadoActual == .CONFIRMADA || estadoActual == .PENDIENTE) {
                        NavigationLink {
                            InvitacionView(reservaId: reserva.id,
                                           nombreLugar: reserva.quincho?.nombre ?? "")
                        } label: {
                            HStack(spacing: 14) {
                                Text("💌").font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Invitar a tus invitados")
                                        .foregroundColor(.appTextPrimary).fontWeight(.medium)
                                    Text("Creá la invitación y compartila por WhatsApp")
                                        .font(.caption2).foregroundColor(.appTextMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundColor(.appTextMuted)
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // ─── Acciones ───
                    let estado = vm.estadoActual ?? reserva.estado
                    
                    if esPropietario {
                        if estado == .PENDIENTE {
                            HStack(spacing: 12) {
                                Button { showRechazar = true } label: {
                                    Text("Rechazar").fontWeight(.semibold).foregroundColor(.appError)
                                        .frame(maxWidth: .infinity).padding()
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appError))
                                }
                                Button {
                                    Task { await vm.confirmar(reserva.id); onActualizar?() }
                                } label: {
                                    Group {
                                        if vm.isLoading { ProgressView().tint(.white) }
                                        else { Text("Confirmar").fontWeight(.bold) }
                                    }
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.appSuccess).foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(vm.isLoading)
                            }
                        } else if estado == .CONFIRMADA {
                            Button {
                                Task { await vm.completar(reserva.id); onActualizar?() }
                            } label: {
                                Group {
                                    if vm.isLoading { ProgressView().tint(.white) }
                                    else { Text("Marcar como completada").fontWeight(.bold) }
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.appPrimary).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(vm.isLoading)
                        }
                    } else {
                        if estado == .PENDIENTE || estado == .CONFIRMADA {
                            Button { showCancelar = true } label: {
                                Text("Cancelar reserva").fontWeight(.semibold).foregroundColor(.appError)
                                    .frame(maxWidth: .infinity).padding()
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appError))
                            }
                        } else if estado == .COMPLETADA {
                            NavigationLink {
                                EscribirResenaView(
                                    quinchoId: reserva.quincho?.id ?? "",
                                    quinchoNombre: reserva.quincho?.nombre ?? "",
                                    reservaId: reserva.id
                                )
                            } label: {
                                HStack {
                                    Image(systemName: "star.fill")
                                    Text("Escribir reseña").fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.appStar).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding()
            }
        }
        .navigationTitle("Detalle de reserva")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancelar reserva", isPresented: $showCancelar) {
            TextField("Motivo (opcional)", text: $motivoTexto)
            Button("Volver", role: .cancel) {}
            Button("Cancelar reserva", role: .destructive) {
                Task { await vm.cancelar(reserva.id, motivo: motivoTexto); onActualizar?() }
            }
        } message: {
            Text("¿Seguro que querés cancelar esta reserva?")
        }
        .alert("Rechazar reserva", isPresented: $showRechazar) {
            TextField("Motivo (opcional)", text: $motivoTexto)
            Button("Volver", role: .cancel) {}
            Button("Rechazar", role: .destructive) {
                Task { await vm.rechazar(reserva.id, motivo: motivoTexto); onActualizar?() }
            }
        } message: {
            Text("El cliente será notificado del rechazo")
        }
    }
    
    func formatearFecha(_ fecha: String) -> String {
        let iso = String(fecha.prefix(10))
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inFormatter.date(from: iso) else { return iso }
        let outFormatter = DateFormatter()
        outFormatter.locale = Locale(identifier: "es_AR")
        outFormatter.dateFormat = "EEEE d 'de' MMMM, yyyy"
        return outFormatter.string(from: date).capitalized
    }
    
    func abrirWhatsApp(telefono: String, nombre: String) {
        let numero = telefono.filter { $0.isNumber }
        let mensaje = "Hola! Te escribo por la reserva en \(nombre)"
        let encoded = mensaje.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/\(numero)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Helpers

struct SeccionTitulo: View {
    let texto: String
    init(_ texto: String) { self.texto = texto }
    var body: some View {
        Text(texto).font(.headline).foregroundColor(.appTextPrimary)
    }
}

struct DetalleFila: View {
    let icono: String
    let label: String
    let valor: String
    var destacado: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .foregroundColor(destacado ? .appPrimary : .appTextSecondary)
                    .frame(width: 22)
                Text(label).foregroundColor(.appTextSecondary).font(.subheadline)
                Spacer()
                Text(valor)
                    .font(destacado ? .headline : .subheadline)
                    .fontWeight(destacado ? .bold : .medium)
                    .foregroundColor(destacado ? .appPrimary : .appTextPrimary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Divider().background(Color.appBorder).padding(.leading, 48)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ReservaDetalleViewModel: ObservableObject {
    @Published var estadoActual: EstadoReserva?
    @Published var motivoCancelacion: String?
    @Published var isLoading = false
    @Published var error: String?
    
    func confirmar(_ id: String) async {
        await accion(id, endpoint: "confirmar", nuevoEstado: .CONFIRMADA)
    }
    
    func completar(_ id: String) async {
        await accion(id, endpoint: "completar", nuevoEstado: .COMPLETADA)
    }
    
    func rechazar(_ id: String, motivo: String) async {
        await accion(id, endpoint: "rechazar", nuevoEstado: .RECHAZADA, motivo: motivo)
    }
    
    func cancelar(_ id: String, motivo: String) async {
        await accion(id, endpoint: "cancelar", nuevoEstado: .CANCELADA, motivo: motivo)
    }
    
    private func accion(_ id: String, endpoint: String, nuevoEstado: EstadoReserva, motivo: String? = nil) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        guard let token = await APIService.shared.getToken(),
              let url = URL(string: "\(APIConfig.baseURL)/reservas/\(id)/\(endpoint)") else {
            error = "No autenticado"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = (motivo?.isEmpty == false) ? ["motivo": motivo!] : [:]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            
            if http.statusCode < 400 {
                estadoActual = nuevoEstado
                if let m = motivo, !m.isEmpty { motivoCancelacion = m }
                await BadgeManager.shared.refrescar(esPropietario: true)
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["error"] as? String {
                    error = msg
                } else {
                    error = "Error \(http.statusCode)"
                }
            }
        } catch {
            self.error = APIService.mensaje(error)
        }
    }
}
