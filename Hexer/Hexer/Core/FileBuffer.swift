//
//  FileBuffer.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import Foundation
import CryptoKit

enum FileBufferError: Error {
    case fileOpenFailed
    case mmapFailed
    case unmapFailed
    case readOnlyViolation
    case outOfBounds
    case writeFailed
}

class FileBuffer: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    private(set) var fileSize: Int = 0
    private var fileHandle: FileHandle?
    private var mappedData: UnsafeMutableRawPointer?
    private var originalDataPtr: UnsafeBufferPointer<UInt8>?

    @Published private(set) var changedBytes: [Int: UInt8] = [:]
    @Published private(set) var isDirty: Bool = false

    var originalFileSize: Int {
        return fileSize
    }

    init(url: URL) {
        self.url = url
    }

    deinit {
        try? close()
    }

    func open() async throws {
        guard fileHandle == nil else { return }

        do {
            let handle = try FileHandle(forUpdating: url)
            self.fileHandle = handle

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber else {
                try? handle.close()
                throw FileBufferError.fileOpenFailed
            }
            self.fileSize = size.intValue

            guard fileSize > 0 else {
                self.originalDataPtr = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
                return
            }
            
            let mmap_ptr = mmap(nil, fileSize, PROT_READ, MAP_PRIVATE, handle.fileDescriptor, 0)

            if mmap_ptr == MAP_FAILED {
                try? handle.close()
                throw FileBufferError.mmapFailed
            }
            self.mappedData = mmap_ptr
            self.originalDataPtr = UnsafeBufferPointer<UInt8>(start: mmap_ptr?.assumingMemoryBound(to: UInt8.self), count: fileSize)

        } catch {
            try? fileHandle?.close()
            fileHandle = nil
            mappedData = nil
            originalDataPtr = nil
            throw error
        }
    }

    func close() throws {
        guard let handle = fileHandle else { return }
        if let data = mappedData, fileSize > 0 {
            if munmap(data, fileSize) != 0 {
                print("Warning: munmap failed - \(String(cString: strerror(errno)))")
            }
        }
        mappedData = nil
        originalDataPtr = nil
        try handle.close()
        fileHandle = nil
    }

    func byte(at offset: Int) -> UInt8? {
        guard offset >= 0 && offset < fileSize else { return nil }
        if let changedByte = changedBytes[offset] {
            return changedByte
        }
        return originalDataPtr?[offset]
    }

    func updateByte(at offset: Int, newValue: UInt8, undoManager: UndoManager?) throws {
        guard offset >= 0 && offset < fileSize else { throw FileBufferError.outOfBounds }

        let oldValue = self.byte(at: offset)

        undoManager?.registerUndo(withTarget: self, handler: { target in
            try? target.updateByte(at: offset, newValue: oldValue ?? 0, undoManager: undoManager)
            if !target.changedBytes.keys.contains(offset) && oldValue != target.originalDataPtr?[offset] {
            }
        })

        if originalDataPtr?[offset] == newValue {
            changedBytes.removeValue(forKey: offset)
        } else {
            changedBytes[offset] = newValue
        }
        isDirty = !changedBytes.isEmpty
    }

    func save() async throws {
        guard isDirty else { return }
        guard let originalPtr = originalDataPtr?.baseAddress else {
            throw FileBufferError.mmapFailed
        }

        var mutableBuffer = [UInt8](repeating: 0, count: fileSize)
        memcpy(&mutableBuffer, originalPtr, fileSize)

        for (offset, value) in changedBytes {
            if offset < fileSize {
                mutableBuffer[offset] = value
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent + ".tmp")
        
        do {
            let dataToWrite = Data(bytes: mutableBuffer, count: fileSize)
            try dataToWrite.write(to: tempURL, options: .atomic)

            try close()
        
            if FileManager.default.fileExists(atPath: url.path) {
                 _ = try? FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tempURL, to: url)

            try await open()
            changedBytes.removeAll()
            isDirty = false
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            if fileHandle == nil {
                try? await open()
            }
            throw FileBufferError.writeFailed
        }
    }
}

extension FileBuffer {
    enum ChecksumType {
        case md5, sha1, sha256
    }

    func calculateChecksum(type: ChecksumType) async -> String? {
        guard fileSize > 0 else { return nil }

        var currentData = Data(capacity: fileSize)
                if let originalPtr = originalDataPtr?.baseAddress {
            var tempMutableBuffer = [UInt8](repeating: 0, count: fileSize)
            memcpy(&tempMutableBuffer, originalPtr, fileSize)
            
            for (offset, value) in changedBytes {
                if offset < fileSize {
                    tempMutableBuffer[offset] = value
                }
            }
            currentData = Data(bytes: tempMutableBuffer, count: fileSize)
        } else if fileSize > 0 && changedBytes.count == fileSize {
             var tempMutableBuffer = [UInt8](repeating: 0, count: fileSize)
             for (offset, value) in changedBytes {
                if offset < fileSize {
                    tempMutableBuffer[offset] = value
                }
             }
             currentData = Data(bytes: tempMutableBuffer, count: fileSize)
        } else {
            return nil
        }


        switch type {
        case .md5:
            let digest = Insecure.MD5.hash(data: currentData)
            return digest.map { String(format: "%02hhx", $0) }.joined()
        case .sha1:
            let digest = Insecure.SHA1.hash(data: currentData)
            return digest.map { String(format: "%02hhx", $0) }.joined()
        case .sha256:
            let digest = SHA256.hash(data: currentData)
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }
    }
}

extension FileBuffer: Equatable {
    static func == (lhs: FileBuffer, rhs: FileBuffer) -> Bool {
        return lhs.id == rhs.id
    }
}
