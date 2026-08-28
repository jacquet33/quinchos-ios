import SwiftUI
import PhotosUI

// MARK: - Photo Picker (iOS 16+)

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let maxSelection: Int
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxSelection
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let image = image as? UIImage {
                        Task { @MainActor in
                            self.parent.selectedImages.append(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Upload Service

@MainActor
class ImageUploadService: ObservableObject {
    @Published var isUploading = false
    @Published var progress: Double = 0
    @Published var error: String?
    
    // Subir imágenes a un quincho
    func subirImagenes(quinchoId: String, images: [UIImage]) async -> [String] {
        guard let token = await APIService.shared.getToken() else {
            error = "No autenticado"
            return []
        }
        
        isUploading = true
        progress = 0
        error = nil
        
        guard let url = URL(string: "\(APIConfig.baseURL)/uploads/quincho/\(quinchoId)") else {
            error = "URL inválida"
            isUploading = false
            return []
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Construir body multipart
        var body = Data()
        for (i, image) in images.enumerated() {
            // Comprimir a JPEG 80% calidad
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"imagenes\"; filename=\"foto_\(i).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            progress = Double(i + 1) / Double(images.count) * 0.5
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 400 else {
                error = "Error al subir imágenes"
                isUploading = false
                return []
            }
            
            progress = 1.0
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["data"] as? [[String: Any]] {
                let urls = items.compactMap { $0["url"] as? String }
                isUploading = false
                return urls
            }
            
            isUploading = false
            return []
        } catch {
            self.error = error.localizedDescription
            isUploading = false
            return []
        }
    }
    
    // Subir avatar
    func subirAvatar(image: UIImage) async -> String? {
        guard let token = await APIService.shared.getToken() else { return nil }
        guard let url = URL(string: "\(APIConfig.baseURL)/uploads/avatar") else { return nil }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let avatarUrl = json["url"] as? String else { return nil }
        
        return avatarUrl
    }
}

// MARK: - Image Upload Button View

struct ImageUploadButton: View {
    let quinchoId: String
    @StateObject private var uploader = ImageUploadService()
    @State private var selectedImages: [UIImage] = []
    @State private var showPicker = false
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Fotos seleccionadas
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImages[i])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button {
                                    selectedImages.remove(at: i)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.appError)
                                        .background(Circle().fill(Color.white))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            
            // Botones
            HStack(spacing: 12) {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Elegir fotos")
                    }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appPrimary))
                }
                
                if !selectedImages.isEmpty {
                    Button {
                        Task {
                            let urls = await uploader.subirImagenes(quinchoId: quinchoId, images: selectedImages)
                            if !urls.isEmpty {
                                selectedImages = []
                                showSuccess = true
                            }
                        }
                    } label: {
                        HStack {
                            if uploader.isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Subir \(selectedImages.count)")
                            }
                        }
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(uploader.isUploading)
                }
            }
            
            // Progress
            if uploader.isUploading {
                ProgressView(value: uploader.progress)
                    .tint(.appPrimary)
            }
            
            if let error = uploader.error {
                Text(error).font(.caption).foregroundColor(.appError)
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePickerView(selectedImages: $selectedImages, maxSelection: 10)
        }
        .alert("¡Fotos subidas!", isPresented: $showSuccess) {
            Button("OK") {}
        }
    }
}
