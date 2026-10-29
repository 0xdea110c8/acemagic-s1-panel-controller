import CLibUSB
import Foundation

enum USBHID {
    enum USBHIDError: Error, CustomStringConvertible {
        case initializationFailed(Int32)
        case emptyContext
        case deviceNotFound
        case detachKernelDriverFailed(Int32)
        case claimInterfaceFailed(Int32, Int32)
        case attachKernelDriverFailed(Int32)
        case releaseInterfaceFailed(Int32, Int32)
        case transferFailed(Int32)
        case partialTransfer(expected: Int, actual: Int)
        case libusbError(Int32)

        var description: String {
            switch self {
                case .initializationFailed(let result):
                    return "initialization failed, result: \(result)"
                case .emptyContext:
                    return "has empty context"
                case .deviceNotFound:
                    return "not found"
                case .detachKernelDriverFailed(let result):
                    return "kernel driver failed to detach, result: \(result)"
                case .claimInterfaceFailed(let interface, let result):
                    return "failed to claim interface \(interface), result: \(result)"
                case .attachKernelDriverFailed(let result):
                    return "kernel driver failed to attach, result: \(result)"
                case .releaseInterfaceFailed(let interface, let result):
                    return "failed to release interface \(interface), result: \(result)"
                case .transferFailed(let result):
                    return "failed to transfer bytes, result: \(result)"
                case .partialTransfer(let expected, let actual):
                    return "transferred bytes partially, expected: \(expected), actual: \(actual)"
                case .libusbError(let error):
                    return "libusb error: \(error)"
            }
        }
    }

    static func open(
        vendorId: UInt16,
        productId: UInt16
    ) throws -> (handle: OpaquePointer, context: OpaquePointer) {
        var context: OpaquePointer?

        let result = libusb_init(&context)
        guard result == 0 else {
            throw USBHIDError.initializationFailed(result)
        }

        guard let context else {
            throw USBHIDError.emptyContext
        }

        guard let handle = libusb_open_device_with_vid_pid(context, vendorId, productId) else {
            libusb_exit(context)
            throw USBHIDError.deviceNotFound
        }

        return (handle, context)
    }

    static func detachKernelDriver(_ interface: Int32, handle: OpaquePointer) throws -> Bool {
        switch libusb_kernel_driver_active(handle, interface) {
            case 1:
                let result = libusb_detach_kernel_driver(handle, interface)
                guard result == 0 else {
                    throw USBHIDError.detachKernelDriverFailed(result)
                }
                return true
            case 0:
                return false
            case let error:
                throw USBHIDError.libusbError(error)
        }
    }

    static func claimInterface(_ interface: Int32, handle: OpaquePointer) throws {
        let result = libusb_claim_interface(handle, interface)
        guard result == 0 else {
            throw USBHIDError.claimInterfaceFailed(interface, result)
        }
    }

    static func interruptWrite(
        _ bytes: [UInt8],
        handle: OpaquePointer,
        to endpoint: UInt8,
        with timeout: UInt32
    ) throws {
        var transferred: Int32 = 0

        let result = bytes.withUnsafeBytes { buffer in
            libusb_interrupt_transfer(
                handle,
                endpoint,
                UnsafeMutablePointer(mutating: buffer.bindMemory(to: UInt8.self).baseAddress),
                Int32(buffer.count),
                &transferred,
                timeout
            )
        }

        guard result == 0 else {
            throw USBHIDError.transferFailed(result)
        }

        guard transferred == bytes.count else {
            throw USBHIDError.partialTransfer(
                expected: bytes.count,
                actual: Int(transferred)
            )
        }
    }

    static func releaseInterface(_ interface: Int32, handle: OpaquePointer) throws {
        let result = libusb_release_interface(handle, interface)
        guard result == 0 else {
            throw USBHIDError.releaseInterfaceFailed(interface, result)
        }
    }

    static func attachKernelDriver(_ interface: Int32, handle: OpaquePointer) throws {
        switch libusb_kernel_driver_active(handle, interface) {
            case 1:
                break
            case 0:
                let result = libusb_attach_kernel_driver(handle, interface)
                guard result == 0 else {
                    throw USBHIDError.attachKernelDriverFailed(result)
                }
            case let error:
                throw USBHIDError.libusbError(error)
        }
    }

    static func close(handle: OpaquePointer, context: OpaquePointer) {
        libusb_close(handle)
        libusb_exit(context)
    }
}

//Logger.log(
//  String(
//    format: "%02X %02X %02X %02X %02X %02X %02X %02X",
//  bytes[0],
//bytes[1],
//     bytes[2],
//   bytes[3],
//  bytes[4],
// bytes[5],
// bytes[6],
//bytes[7],
//)
//)
