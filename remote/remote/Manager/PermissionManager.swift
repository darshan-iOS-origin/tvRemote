import Foundation
import AVFoundation
import Photos
import CoreLocation
import UIKit

class PermissionManager {
    static let shared = PermissionManager()
    private init() {}

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else {
            PermissionAnalyticsManager.trackCamera(status)
            DispatchQueue.main.async { completion(status == .authorized) }
            return
        }
        PermissionAnalyticsManager.trackCamera(.notDetermined)
        AVCaptureDevice.requestAccess(for: .video) { _ in
            let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
            PermissionAnalyticsManager.trackCamera(newStatus)
            DispatchQueue.main.async { completion(newStatus == .authorized) }
        }
    }

    func currentPhotoLibraryStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func isPhotoLibraryAccessGranted(_ status: PHAuthorizationStatus? = nil) -> Bool {
        let resolved = status ?? currentPhotoLibraryStatus()
        return resolved == .authorized || resolved == .limited
    }

    func requestPhotoLibraryAccess(completion: @escaping (PHAuthorizationStatus) -> Void) {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else {
            PermissionAnalyticsManager.trackPhotoLibrary(current)
            DispatchQueue.main.async { completion(current) }
            return
        }
        PermissionAnalyticsManager.trackPhotoLibrary(.notDetermined)
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            PermissionAnalyticsManager.trackPhotoLibrary(status)
            DispatchQueue.main.async { completion(status) }
        }
    }

    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        requestPhotoLibraryAccess { completion(self.isPhotoLibraryAccessGranted($0)) }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
