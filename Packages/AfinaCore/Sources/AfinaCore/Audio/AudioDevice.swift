import CoreAudio

/// Dispositivo de entrada de áudio visto pelo Core Audio.
public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    /// Identificador estável entre ligações (o `id` muda quando se desliga e volta a ligar).
    public let uid: String
    public let name: String
    public let inputChannelCount: Int
    public let nominalSampleRate: Double
    public let transportType: UInt32

    /// Microfones Bluetooth costumam funcionar a 16–24 kHz e com mais latência.
    public var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE
    }
}

/// Consulta dos dispositivos de entrada através do Core Audio.
public enum AudioDeviceCatalog {
    public static func inputDevices() -> [AudioDevice] {
        deviceIDs().compactMap(device(withID:)).filter { $0.inputChannelCount > 0 }
    }

    public static func defaultInputDeviceID() -> AudioDeviceID? {
        let id = propertyValue(kAudioHardwarePropertyDefaultInputDevice, of: systemObject, initial: AudioDeviceID(0))
        return id == kAudioObjectUnknown ? nil : id
    }

    public static func device(withID id: AudioDeviceID) -> AudioDevice? {
        guard let uid = stringValue(kAudioDevicePropertyDeviceUID, of: id) else { return nil }
        return AudioDevice(
            id: id,
            uid: uid,
            name: stringValue(kAudioObjectPropertyName, of: id) ?? uid,
            inputChannelCount: inputChannelCount(of: id),
            nominalSampleRate: propertyValue(kAudioDevicePropertyNominalSampleRate, of: id, initial: Float64(0)) ?? 0,
            transportType: propertyValue(kAudioDevicePropertyTransportType, of: id, initial: UInt32(0)) ?? 0
        )
    }

    // MARK: Core Audio

    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func propertyValue<Value: BitwiseCopyable>(
        _ selector: AudioObjectPropertySelector,
        of object: AudioObjectID,
        initial: Value
    ) -> Value? {
        var address = address(selector)
        var value = initial
        var size = UInt32(MemoryLayout<Value>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func stringValue(_ selector: AudioObjectPropertySelector, of object: AudioObjectID) -> String? {
        var address = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func inputChannelCount(of id: AudioDeviceID) -> Int {
        var address = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, storage) == noErr else { return 0 }

        let buffers = UnsafeMutableAudioBufferListPointer(storage.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}

/// Avisa quando a lista de dispositivos ou a entrada por defeito do sistema mudam
/// (ligar/desligar uma interface USB, auscultadores, etc.). Deixa de observar quando é libertado.
@MainActor
public final class AudioDeviceChangeObserver {
    private let listener: AudioObjectPropertyListenerBlock
    private static let selectors = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice]

    public init(onChange: @escaping @MainActor () -> Void) {
        // O Core Audio chama o bloco na fila principal (ver `DispatchQueue.main` abaixo).
        listener = { _, _ in MainActor.assumeIsolated { onChange() } }
        for selector in Self.selectors {
            var address = AudioDeviceCatalog.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioDeviceCatalog.systemObject, &address, .main, listener)
        }
    }

    isolated deinit {
        for selector in Self.selectors {
            var address = AudioDeviceCatalog.address(selector)
            AudioObjectRemovePropertyListenerBlock(AudioDeviceCatalog.systemObject, &address, .main, listener)
        }
    }
}
