#if os(Linux)
    import CLibUSB

    class CLibUSBDevice: USBDevice {
        enum USBDeviceError: Error {
            case initializationFailed(Int32)
            case deviceNotFound
            case configurationReadFailed(Int32)
            case detachKernelDriverFailed(Int32)
            case claimInterfaceFailed(Int32)
            case transferFailed(Int32)
            case partialTransfer(expected: Int, actual: Int)
            case emptyContext
        }

        let vendorID: UInt16
        let productID: UInt16
        let context: OpaquePointer
        let handle: OpaquePointer

        required init(
            vendorID: UInt16,
            productID: UInt16
        ) throws {
            self.vendorID = vendorID
            self.productID = productID

            var context: OpaquePointer?
            let result = libusb_init(&context)

            guard result == 0 else {
                Logger.log(
                    "USB device (vendorID: \(vendorID), productID: \(productID))"
                        + "initialization failed."
                )

                throw USBDeviceError.initializationFailed(result)
            }

            guard let context else {

                Logger.log(
                    "USB device (vendorID: \(vendorID), productID: \(productID))"
                        + "has empty context."
                )

                throw USBDeviceError.emptyContext
            }

            guard
                let handle = libusb_open_device_with_vid_pid(
                    context,
                    vendorID,
                    productID
                )
            else {
                libusb_exit(context)

                Logger.log(
                    "USB device (vendorID: \(vendorID), productID: \(productID))" + "not found."
                )

                throw USBDeviceError.deviceNotFound
            }

            Logger.log(
                "USB device (vendorID: \(vendorID), productID: \(productID))"
                    + "opened successfully."
            )

            self.context = context
            self.handle = handle
        }

        deinit {
            close()
        }

        func claimInterface(_ interface: Int32) throws {
            if libusb_kernel_driver_active(handle, interface) == 1 {
                let result = libusb_detach_kernel_driver(handle, interface)

                guard result == 0 else {
                    Logger.log(
                        "USB device (vendorID: \(self.vendorID), productID: \(self.productID))"
                            + "kernel driver failed to detach."
                    )

                    throw USBDeviceError.detachKernelDriverFailed(result)
                }
            }

            let result = libusb_claim_interface(handle, interface)

            guard result == 0 else {
                Logger.log(
                    "USB device (vendorID: \(self.vendorID), productID: \(self.productID))"
                        + "failed to claim interface \(interface) with exit code \(result)."
                )

                throw USBDeviceError.claimInterfaceFailed(result)
            }

            Logger.log(
                "USB device (vendorID: \(self.vendorID), productID: \(self.productID))"
                    + "claimed interface \(interface) successfully."
            )
        }

        func interruptWrite(
            _ bytes: [UInt8],
            to endpoint: UInt8,
            with timeout: UInt32
        ) throws {
            var transferred: Int32 = 0

            let result = bytes.withUnsafeBytes { buffer in
                libusb_interrupt_transfer(
                    handle,
                    endpoint,
                    UnsafeMutablePointer(
                        mutating: buffer.bindMemory(to: UInt8.self).baseAddress
                    ),
                    Int32(buffer.count),
                    &transferred,
                    timeout
                )
            }

            Logger.log(
                String(
                    format: "%02X %02X %02X %02X %02X %02X %02X %02X",
                    bytes[0],
                    bytes[1],
                    bytes[2],
                    bytes[3],
                    bytes[4],
                    bytes[5],
                    bytes[6],
                    bytes[7],
                )
            )

            guard result == 0 else {
                Logger.log(
                    "USB device (vendorID: \(self.vendorID), productID: \(self.productID))"
                        + "failed to transfer packet with result \(result)"
                )

                throw USBDeviceError.transferFailed(result)
            }

            guard transferred == bytes.count else {
                Logger.log(
                    "USB device (vendorID: \(self.vendorID), productID: \(self.productID))"
                        + "transferred packet partially."
                )

                throw USBDeviceError.partialTransfer(
                    expected: bytes.count,
                    actual: Int(transferred)
                )
            }
        }

        @inline(__always)
        func close() {
            libusb_close(handle)
            libusb_exit(context)

            Logger.log(
                "USB device (vendorID: \(self.vendorID), productID: \(self.productID))"
                    + "closed."
            )
        }
    }
#endif    // os(Linux)
