import SwiftUI

// MARK: - Caché de imágenes en memoria y disco

actor CacheImagenes {
    static let shared = CacheImagenes()

    private let memoria = NSCache<NSString, UIImage>()
    private let carpeta: URL

    private init() {
        memoria.countLimit = 120
        memoria.totalCostLimit = 60 * 1024 * 1024 // 60 MB

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        carpeta = cacheDir.appendingPathComponent("imagenes", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
    }

    private func rutaEnDisco(_ url: URL) -> URL {
        let nombre = String(url.absoluteString.hashValue.magnitude)
        return carpeta.appendingPathComponent(nombre)
    }

    func imagen(para url: URL) -> UIImage? {
        let clave = url.absoluteString as NSString

        // 1. Memoria
        if let img = memoria.object(forKey: clave) { return img }

        // 2. Disco
        let ruta = rutaEnDisco(url)
        if let data = try? Data(contentsOf: ruta), let img = UIImage(data: data) {
            memoria.setObject(img, forKey: clave, cost: data.count)
            return img
        }

        return nil
    }

    func guardar(_ imagen: UIImage, data: Data, para url: URL) {
        memoria.setObject(imagen, forKey: url.absoluteString as NSString, cost: data.count)
        try? data.write(to: rutaEnDisco(url))
    }

    func descargar(_ url: URL) async -> UIImage? {
        if let cacheada = imagen(para: url) { return cacheada }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return nil }

        guardar(img, data: data, para: url)
        return img
    }

    func limpiar() {
        memoria.removeAllObjects()
        try? FileManager.default.removeItem(at: carpeta)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
    }
}

// MARK: - Vista de imagen con caché

struct ImagenRemota: View {
    let url: String?
    var usarMiniatura: Bool = false
    var contentMode: ContentMode = .fill

    @State private var imagen: UIImage?
    @State private var fallo = false

    /// El backend genera un `_thumb.jpg` de 400px junto a cada imagen
    private var urlFinal: URL? {
        guard let url, !url.isEmpty else { return nil }
        if usarMiniatura {
            let conThumb = url.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
            return URL(string: conThumb)
        }
        return URL(string: url)
    }

    var body: some View {
        ZStack {
            if let imagen {
                Image(uiImage: imagen)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if fallo {
                Color.appSurfaceLight.overlay(
                    Image(systemName: "photo")
                        .font(.title2).foregroundColor(.appTextMuted)
                )
            } else {
                Color.appSurfaceLight.overlay(
                    ProgressView().tint(.appTextMuted)
                )
            }
        }
        .task(id: urlFinal) {
            await cargar()
        }
    }

    private func cargar() async {
        guard let urlFinal else { fallo = true; return }

        // Si ya está cacheada aparece al instante
        if let cacheada = await CacheImagenes.shared.imagen(para: urlFinal) {
            imagen = cacheada
            return
        }

        if let descargada = await CacheImagenes.shared.descargar(urlFinal) {
            withAnimation(.easeIn(duration: 0.2)) { imagen = descargada }
        } else if usarMiniatura {
            // La miniatura puede no existir en fotos viejas: probar con la original
            if let original = URL(string: url ?? ""),
               let img = await CacheImagenes.shared.descargar(original) {
                withAnimation(.easeIn(duration: 0.2)) { imagen = img }
            } else {
                fallo = true
            }
        } else {
            fallo = true
        }
    }
}
