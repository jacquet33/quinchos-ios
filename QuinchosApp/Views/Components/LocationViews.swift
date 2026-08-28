import SwiftUI
import UIKit

// MARK: - Banner para pedir GPS

struct LocationBanner: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        if locationManager.isDenied {
            // GPS denegado → indicar que vaya a Ajustes
            HStack(spacing: 12) {
                Image(systemName: "location.slash.fill")
                    .font(.title3).foregroundColor(.appWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ubicación desactivada")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.appTextPrimary)
                    Text("Activala en Ajustes para ver quinchos cerca tuyo")
                        .font(.caption).foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                Button("Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption).fontWeight(.bold)
                .foregroundColor(.appPrimary)
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appWarning.opacity(0.3), lineWidth: 1)
            )
            
        } else if !locationManager.isAuthorized {
            // GPS no pedido todavía
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.title3).foregroundColor(.appPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Encontrá quinchos cerca tuyo")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.appTextPrimary)
                    Text("Activá el GPS para buscar por proximidad")
                        .font(.caption).foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                Button {
                    locationManager.requestPermission()
                } label: {
                    Text("Activar")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
        } else if locationManager.isLocating {
            HStack(spacing: 10) {
                ProgressView().tint(.appPrimary)
                Text("Obteniendo ubicación...").font(.caption).foregroundColor(.appTextSecondary)
            }
            .padding(10)
        }
        // Si ya tiene ubicación no mostrar nada
    }
}

// MARK: - Chip de distancia

struct DistanciaChip: View {
    let distanciaKm: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: 9))
            Text(distanciaKm < 1 ? "\(Int(distanciaKm * 1000))m" : String(format: "%.1f km", distanciaKm))
                .font(.caption2).fontWeight(.semibold)
        }
        .foregroundColor(.appPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appPrimary.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Selector de radio de búsqueda

struct RadioSelectorWithAction: View {
    @Binding var radioKm: Double
    let onChange: () -> Void
    let opciones: [Double] = [5, 10, 20, 50, 100]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "scope").foregroundColor(.appTextMuted).font(.caption)
                
                ForEach(opciones, id: \.self) { km in
                    let activo = radioKm == km
                    Button {
                        radioKm = km
                        onChange()
                    } label: {
                        Text("\(Int(km)) km")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(activo ? .white : .appTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activo ? Color.appPrimary : Color.appSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(activo ? Color.clear : Color.appBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct RadioSelector: View {
    @Binding var radioKm: Double
    let opciones: [Double] = [5, 10, 20, 50, 100]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "scope").foregroundColor(.appTextMuted).font(.caption)
                
                ForEach(opciones, id: \.self) { km in
                    let activo = radioKm == km
                    Button {
                        radioKm = km
                    } label: {
                        Text("\(Int(km)) km")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(activo ? .white : .appTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activo ? Color.appPrimary : Color.appSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(activo ? Color.clear : Color.appBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
