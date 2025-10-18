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

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showAnalysis = false
    @State private var capturedImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

                    Text("Take Photo")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding()

                Spacer()

                // Camera Preview
                CameraPreviewView(session: cameraManager.session)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.yellow, lineWidth: 2)
                    )
                    .padding(.horizontal, 24)

                Spacer()

                // Instructions
                VStack(spacing: 8) {
                    Text("Position your face within the frame")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    Text("Good lighting helps with better analysis")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 16)

                // Controls
                HStack(spacing: 60) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text("Gallery")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }

                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }

                    Button(action: { cameraManager.switchCamera() }) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2)
                            Text("Flip")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    processImage(image)
                }
            }
        }
        .sheet(isPresented: $showAnalysis) {
            if let image = capturedImage {
                AnalysisProcessingView(image: image)
            }
        }
    }

    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image {
                processImage(image)
            }
        }
    }

    private func processImage(_ image: UIImage) {
        capturedImage = image
        showAnalysis = true
    }
}

// Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?

    private var photoCompletion: ((UIImage?) -> Void)?
    private var currentCamera: AVCaptureDevice.Position = .front

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }

    func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }

    func switchCamera() {
        session.beginConfiguration()

        session.inputs.forEach { input in
            session.removeInput(input)
        }

        currentCamera = currentCamera == .front ? .back : .front

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        session.commitConfiguration()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoCompletion?(nil)
            return
        }
        photoCompletion?(image)
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
