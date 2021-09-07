//
//  sha.swift
//  streaming-treeTests
//
//  Copied from https://stackoverflow.com/a/56901530/53140 on 7/28/21.
//

import CommonCrypto
import Foundation

final class SHA256Digest {
    enum InputStreamError: Error {
        case createFailed(URL)
        case readFailed
    }

    private lazy var context: CC_SHA256_CTX = {
        var shaContext = CC_SHA256_CTX()
        CC_SHA256_Init(&shaContext)
        return shaContext
    }()

    private var result: Data?

    init() {}

    func update(url: URL) throws {
        guard let inputStream = InputStream(url: url) else {
            throw InputStreamError.createFailed(url)
        }
        return try self.update(inputStream: inputStream)
    }

    func update(inputStream: InputStream) throws {
        guard self.result == nil else {
            return
        }
        inputStream.open()
        defer {
            inputStream.close()
        }
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while true {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                // Stream error occured
                throw (inputStream.streamError ?? InputStreamError.readFailed)
            } else if bytesRead == 0 {
                // EOF
                break
            }
            self.update(bytes: buffer, length: bytesRead)
        }
    }

    func update(bytes: UnsafeRawPointer, length: Int) {
        guard self.result == nil else {
            return
        }
        _ = CC_SHA256_Update(&self.context, bytes, CC_LONG(length))
    }

    func finalize() -> Data {
        if let calculatedResult = result {
            return calculatedResult
        }
        var resultBuffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&resultBuffer, &self.context)
        let theResult = Data(resultBuffer)
        result = theResult
        return theResult
    }
}

extension Data {
    private static let hexCharacterLookupTable: [Character] = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
    ]

    var hexString: String {
        self.reduce(into: String()) { result, byte in
            let c1: Character = Data.hexCharacterLookupTable[Int(byte >> 4)]
            let c2: Character = Data.hexCharacterLookupTable[Int(byte & 0x0F)]
            result.append(c1)
            result.append(c2)
        }
    }
}
