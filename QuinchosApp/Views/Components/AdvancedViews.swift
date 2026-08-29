import SwiftUI
import UIKit

// MARK: - Filtros Avanzados

struct FiltrosAvanzadosView: View {
    @Binding var precioMax: Double
    @Binding var capacidadMin: Double
    @Binding var amenidadesSeleccionadas: Set<String>
    @Binding var ordenarPor: String
    let onAplicar: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Precio máximo
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Precio máximo por día").font(.headline).foregroundColor(.appTextPrimary)
                                Spacer()
                                Text(precioMax >= 200000 ? "Sin límite" : Int(precioMax).formattedPrecio)
                                    .font(.subheadline).fontWeight(.bold).foregroundColor(.appPrimary)
                            }
                            Slider(value: $precioMax, in: 10000...200000, step: 5000)
                                .tint(.appPrimary)
                        }
                        
                        Divider().background(Color.appBorder)
                        
                        // Capacidad mínima
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Personas mínimo").font(.headline).foregroundColor(.appTextPrimary)
                                Spacer()
                                Text("\(Int(capacidadMin))").font(.subheadline).fontWeight(.bold).foregroundColor(.appPrimary)
                            }
                            Slider(value: $capacidadMin, in: 1...100, step: 5)
                                .tint(.appPrimary)
                        }
                        
                        Divider().background(Color.appBorder)
                        
                        // Ordenar por
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ordenar por").font(.headline).foregroundColor(.appTextPrimary)
                            ForEach([
                                ("calificacion", "⭐ Mejor valorados"),
                                ("precio", "💰 Precio más bajo"),
                                ("precio_desc", "💎 Precio más alto"),
                                ("distancia", "📍 Más cercanos"),
                                ("reciente", "🆕 Más recientes"),
                            ], id: \.0) { (key, label) in
                                Button {
                                    ordenarPor = key
                                } label: {
                                    HStack {
                                        Text(label).foregroundColor(.appTextPrimary)
                                        Spacer()
                                        if ordenarPor == key {
                                            Image(systemName: "checkmark").foregroundColor(.appPrimary)
                                        }
                                    }
                                    .padding(12)
                                    .background(ordenarPor == key ? Color.appPrimary.opacity(0.1) : Color.appSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        
                        Divider().background(Color.appBorder)
                        
                        // Amenidades
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Comodidades").font(.headline).foregroundColor(.appTextPrimary)
                            FlowLayout(spacing: 8) {
                                ForEach(Amenidad.allCases, id: \.self) { amenidad in
                                    let selected = amenidadesSeleccionadas.contains(amenidad.rawValue)
                                    Button {
                                        if selected { amenidadesSeleccionadas.remove(amenidad.rawValue) }
                                        else { amenidadesSeleccionadas.insert(amenidad.rawValue) }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: amenidad.icono).font(.caption)
                                            Text(amenidad.label).font(.caption)
                                        }
                                        .foregroundColor(selected ? .white : .appTextSecondary)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(selected ? Color.appPrimary : Color.appSurface)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Limpiar") {
                        precioMax = 200000
                        capacidadMin = 1
                        amenidadesSeleccionadas = []
                        ordenarPor = "calificacion"
                    }
                    .foregroundColor(.appTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Aplicar") {
                        onAplicar()
                        dismiss()
                    }
                    .fontWeight(.bold).foregroundColor(.appPrimary)
                }
            }
        }
    }
}

// MARK: - Escribir Reseña View

struct EscribirResenaView: View {
    let quinchoId: String
    let quinchoNombre: String
    let reservaId: String?
    @StateObject private var vm = ResenasViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var calificacion = 0
    @State private var comentario = ""
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("¿Cómo fue tu experiencia en").foregroundColor(.appTextSecondary)
                        Text(quinchoNombre).font(.title3).fontWeight(.bold).foregroundColor(.appTextPrimary)
                    }
                    .padding(.top)
                    
                    // Estrellas
                    StarRatingView(rating: calificacion, size: 40, editable: true) { newRating in
                        calificacion = newRating
                    }
                    
                    // Comentario
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tu comentario").font(.caption).fontWeight(.semibold).foregroundColor(.appTextSecondary)
                        TextEditor(text: $comentario)
                            .frame(minHeight: 120)
                            .foregroundColor(.appTextPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder))
                        
                        Text("\(comentario.count)/500").font(.caption2).foregroundColor(.appTextMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    if let error = vm.error {
                        Text(error).font(.caption).foregroundColor(.appError)
                    }
                    
                    Button {
                        Task {
                            let ok = await vm.crearResena(quinchoId: quinchoId, calificacion: calificacion, comentario: comentario, reservaId: reservaId)
                            if ok { showSuccess = true }
                        }
                    } label: {
                        Group {
                            if vm.isLoading { ProgressView().tint(.white) }
                            else { Text("Publicar reseña").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(calificacion > 0 && comentario.count >= 10 ? Color.appPrimary : Color.appSurfaceLight)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(calificacion == 0 || comentario.count < 10 || vm.isLoading)

                    Spacer().frame(height: 40)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Escribir reseña")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { hideKeyboard() }
                    .fontWeight(.semibold).foregroundColor(.appPrimary)
            }
        }
        .alert("¡Gracias por tu reseña!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        }
    }
}

// MARK: - Registro con Rol

struct RegistroView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var nombre = ""
    @State private var email = ""
    @State private var password = ""
    @State private var telefono = ""
    @State private var rolSeleccionado = "USUARIO"
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text("Crear cuenta").font(.title).fontWeight(.heavy).foregroundColor(.appTextPrimary)
                    
                    // Rol
                    VStack(alignment: .leading, spacing: 8) {
                        Text("¿Qué querés hacer?").font(.subheadline).foregroundColor(.appTextSecondary)
                        HStack(spacing: 12) {
                            RolCard(titulo: "Buscar y reservar", subtitulo: "Quiero alquilar quinchos", icono: "magnifyingglass", seleccionado: rolSeleccionado == "USUARIO") { rolSeleccionado = "USUARIO" }
                            RolCard(titulo: "Publicar mi quincho", subtitulo: "Soy propietario", icono: "house.fill", seleccionado: rolSeleccionado == "PROPIETARIO") { rolSeleccionado = "PROPIETARIO" }
                        }
                    }
                    
                    TextField("Nombre completo", text: $nombre)
                        .textFieldStyle(.plain).padding().background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).foregroundColor(.appTextPrimary)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.plain).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        .padding().background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).foregroundColor(.appTextPrimary)
                    
                    TextField("Teléfono (opcional)", text: $telefono)
                        .textFieldStyle(.plain).keyboardType(.phonePad)
                        .padding().background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).foregroundColor(.appTextPrimary)
                    
                    SecureField("Contraseña (mín. 6 caracteres)", text: $password)
                        .textFieldStyle(.plain).padding().background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).foregroundColor(.appTextPrimary)
                    
                    if let error = authVM.error {
                        Text(error).font(.caption).foregroundColor(.appError)
                    }
                    
                    Button {
                        Task { await authVM.registro(email: email, password: password, nombre: nombre) }
                    } label: {
                        Group {
                            if authVM.isLoading { ProgressView().tint(.white) }
                            else { Text("Crear cuenta").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.appPrimary).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(authVM.isLoading)
                }
                .padding(24)
            }
        }
        .navigationTitle("Registro")
    }
}

struct RolCard: View {
    let titulo: String; let subtitulo: String; let icono: String; let seleccionado: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: icono).font(.title2).foregroundColor(seleccionado ? .appPrimary : .appTextMuted)
                Text(titulo).font(.caption).fontWeight(.bold).foregroundColor(seleccionado ? .appTextPrimary : .appTextSecondary)
                Text(subtitulo).font(.caption2).foregroundColor(.appTextMuted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding()
            .background(seleccionado ? Color.appPrimary.opacity(0.1) : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(seleccionado ? Color.appPrimary : Color.appBorder, lineWidth: seleccionado ? 2 : 1))
        }
    }
}

// MARK: - Editar Perfil

struct EditarPerfilView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var nombre: String = ""
    @State private var telefono: String = ""
    @State private var saved = false
    @StateObject private var uploader = ImageUploadService()
    @State private var showPicker = false
    @State private var avatarImages: [UIImage] = []
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    Button { showPicker = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let avatar = avatarImages.first {
                                Image(uiImage: avatar)
                                    .resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100).clipShape(Circle())
                            } else {
                                Circle().fill(Color.appSurface).frame(width: 100, height: 100)
                                    .overlay(Image(systemName: "person").font(.title).foregroundColor(.appTextMuted))
                            }
                            Circle().fill(Color.appPrimary).frame(width: 30, height: 30)
                                .overlay(Image(systemName: "camera.fill").font(.caption).foregroundColor(.white))
                        }
                    }
                    
                    FormField(label: "Nombre", placeholder: "Tu nombre", text: $nombre)
                    FormField(label: "Teléfono", placeholder: "+54 3447 ...", text: $telefono)
                    
                    Button("Guardar") {
                        Task {
                            if let img = avatarImages.first {
                                _ = await uploader.subirAvatar(image: img)
                            }
                            // TODO: actualizar nombre y teléfono via API
                            saved = true
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.appPrimary).foregroundColor(.white).fontWeight(.bold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
        }
        .navigationTitle("Editar perfil")
        .onAppear {
            nombre = authVM.usuario?.nombre ?? ""
            telefono = authVM.usuario?.telefono ?? ""
        }
        .sheet(isPresented: $showPicker) {
            ImagePickerView(selectedImages: $avatarImages, maxSelection: 1)
        }
        .alert("Perfil actualizado", isPresented: $saved) { Button("OK") {} }
    }
}
