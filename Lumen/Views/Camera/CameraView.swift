//
//  CameraView.swift
//  Lumen
//
//  AI Skincare Assistant - Camera Interface
//

import SwiftUI
import AVFoundation
import PhotosUI
import Combine

// Wrapper to make UIImage identifiable for sheet presentation
struct AnalysisImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedItem: PhotosPickerItem?
    @State private var analysisImageItem: AnalysisImageItem?
    @State private var analysisResult: AnalysisResult?
    @State private var analysisError: Error?
    @State private var progressMessage: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraManager.permissionDenied {
                // Permission Denied State
                VStack(spacing: 24) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))

                    VStack(spacing: 12) {
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Please enable camera access in Settings to take photos for skin analysis")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("Skin Analysis")
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .padding()

                    Spacer()

                    // Camera Preview with face guide overlay
                    ZStack {
                        CameraPreviewView(session: cameraManager.session)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3/4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.yellow.opacity(0.6), lineWidth: 3)
                            )

                        // Face guide overlay
                        Ellipse()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 200, height: 260)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Instructions
                    VStack(spacing: 8) {
                        Text("Position your face in the oval")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.95))

                        Text("Good lighting improves accuracy")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 16)

                    // Controls
                    HStack(spacing: 60) {
                        // Gallery picker
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                                Text("Gallery")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }

                        // Capture button
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 5)
                                    .frame(width: 76, height: 76)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 64, height: 64)
                            }
                        }
                        .disabled(!cameraManager.isSessionRunning)
                        .opacity(cameraManager.isSessionRunning ? 1.0 : 0.5)

                        // Flip camera button
                        Button(action: { cameraManager.switchCamera() }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                                Text("Flip")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(!cameraManager.isSessionRunning)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Reset analysis state for new session
            analysisResult = nil
            analysisError = nil
            analysisImageItem = nil
            progressMessage = ""

            cameraManager.checkPermission()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
            // Reset state when leaving
            analysisResult = nil
            analysisError = nil
            analysisImageItem = nil
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // IMPORTANT: Ensure we're on main thread before calling processImage
                    await MainActor.run {
                        self.processImage(image)
                    }
                }
            }
        }
        .sheet(item: $analysisImageItem) { imageItem in
            NavigationStack {
                AnalysisProcessingView(
                    image: imageItem.image,
                    analysisResult: $analysisResult,
                    analysisError: $analysisError,
                    progressMessage: $progressMessage,
                    onDismiss: {
                        analysisImageItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                )
            }
        }
    }

    private func capturePhoto() {
        HapticManager.shared.photoCapture()
        cameraManager.capturePhoto { image in
            if let image = image {
                // IMPORTANT: Ensure we're on main thread before calling processImage
                DispatchQueue.main.async {
                    self.processImage(image)
                }
            }
        }
    }

    private func processImage(_ image: UIImage) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.processImage(image)
            }
            return
        }

        // Reset state
        self.analysisResult = nil
        self.analysisError = nil
        self.progressMessage = "Preparing..."

        // Create image item and present sheet
        self.analysisImageItem = AnalysisImageItem(image: image)
        HapticManager.shared.success()

        // Start analysis
        SkinAnalysisService.shared.analyzeSkin(
            image: image,
            onProgress: { message in
                DispatchQueue.main.async {
                    self.progressMessage = message
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let analysis):
                        self.analysisResult = analysis
                        HapticManager.shared.analysisComplete()

                    case .failure(let error):
                        self.analysisError = error
                        HapticManager.shared.error()
                    }
                }
            }
        )
    }
}

// Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var permissionDenied = false
    @Published var isSessionRunning = false

    private var photoCompletion: ((UIImage?) -> Void)?
    private var currentCamera: AVCaptureDevice.Position = .front
    private let sessionQueue = DispatchQueue(label: "com.lumen.camera.session")

    override init() {
        super.init()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in
                self?.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.permissionDenied = true
            }
        }
    }

    private func setupCamera() {
        session.beginConfiguration()

        // Remove existing inputs/outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Create new output instance
        let newOutput = AVCapturePhotoOutput()
        if session.canAddOutput(newOutput) {
            session.addOutput(newOutput)
            DispatchQueue.main.async { [weak self] in
                self?.output = newOutput
            }
        }

        session.commitConfiguration()

        // Start session on background queue
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()

            // Remove existing inputs
            self.session.inputs.forEach { input in
                self.session.removeInput(input)
            }

            // Toggle camera position
            self.currentCamera = self.currentCamera == .front ? .back : .front

            // Add new input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentCamera),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            self.session.commitConfiguration()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }

            self.photoCompletion = completion

            // Create photo settings with best available codec
            let settings: AVCapturePhotoSettings

            if self.output.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else if self.output.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }

            // Enable high resolution capture
            if #available(iOS 16.0, *) {
                // Use maxPhotoDimensions for iOS 16+
                settings.maxPhotoDimensions = self.output.maxPhotoDimensions
            } else {
                // Fallback for earlier versions
                settings.isHighResolutionPhotoEnabled = true
            }

            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    deinit {
        // Stop session synchronously during deallocation to avoid weak reference issues
        if session.isRunning {
            session.stopRunning()
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.photoCompletion?(nil)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.photoCompletion?(image)
        }
    }
}

// Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                layer.frame = uiView.bounds
            }
        }
    }
}

#Preview {
    CameraView()
}
