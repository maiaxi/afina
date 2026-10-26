import AVFoundation

/// Estado e pedido da permissão de acesso ao microfone.
public enum MicrophonePermission {
    public enum Status: Sendable {
        case notDetermined
        case authorized
        case denied
        /// Bloqueado por políticas do sistema (controlo parental, MDM).
        case restricted
    }

    public static var status: Status {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }

    /// Mostra o pedido do sistema se ainda não tiver sido respondido; devolve se o acesso foi concedido.
    public static func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
