//
//  HexEditorViewModel.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI
import Combine
import CryptoKit

@MainActor
class HexEditorViewModel: ObservableObject {
    // MARK: - Published Properties for UI State
    @Published var fileBuffer: FileBuffer?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var bytesPerRow: Int = 16 {
        didSet {
            if oldValue != bytesPerRow {
                bytesPerRow = max(1, min(64, bytesPerRow))
                calculateVisibleRows()
            }
        }
    }
    @Published var offsetDisplayBase: Int = 16 {
        didSet {
            if oldValue != offsetDisplayBase {
                offsetDisplayBase = (offsetDisplayBase == 10 || offsetDisplayBase == 16) ? offsetDisplayBase : 16
            }
        }
    }
    @Published var selectedOffset: Int? = nil
    @Published var editingOffset: Int? = nil
    @Published var editText: String = ""
    @Published var isEditingHex: Bool = true
    @Published private(set) var totalRowCount: Int = 0
    @Published var searchQuery: String = ""
    @Published var searchResults: [Int] = []
    @Published var currentSearchResultIndex: Int? = nil
    @Published var isSearching: Bool = false
    @Published var fileMetadata: FileMetadata = FileMetadata()
    @Published var extractedStrings: [ExtractedStringInfo] = []
    @Published var isExtractingStrings: Bool = false
    @Published var minStringLength: Int = 4
    
    // MARK: - Services and Managers
    let undoManager = UndoManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(fileURL: URL? = nil) {
        if let url = fileURL {
            Task {
                await loadFile(url: url)
            }
        }
    }
    
    // MARK: - File Operations
    func loadFile(url: URL) async {
        print("[ViewModel] loadFile START for \(url.lastPathComponent)")
        
        self.fileMetadata = FileMetadata()
        self.isLoading = true
        self.errorMessage = nil
        
        guard url.startAccessingSecurityScopedResource() else {
            self.errorMessage = "Failed to access file. Please ensure you have permissions."
            print("[ViewModel] loadFile: FAILED to start accessing security scoped resource for \(url.lastPathComponent). Error: \(self.errorMessage ?? "Unknown error")")
            resetEditorState()
            self.isLoading = false
            print("[ViewModel] loadFile: END (security scope fail). isLoading: \(self.isLoading), totalRowCount: \(self.totalRowCount)")
            return
        }
        defer {
            print("[ViewModel] loadFile: stopAccessingSecurityScopedResource for \(url.lastPathComponent)")
            url.stopAccessingSecurityScopedResource()
        }
        
        print("[ViewModel] loadFile: Security scope OK.")
        
        resetEditorState()
        
        self.isLoading = true
        self.errorMessage = nil
        
        let newBuffer = FileBuffer(url: url)
        do {
            print("[ViewModel] loadFile: Attempting to open newBuffer for \(url.lastPathComponent)...")
            try await newBuffer.open()
            print("[ViewModel] loadFile: newBuffer opened. fileSize: \(newBuffer.fileSize)")
            
            self.fileBuffer = newBuffer
            self.selectedOffset = (newBuffer.fileSize > 0) ? 0 : nil
            calculateVisibleRows()
            print("[ViewModel] loadFile: File processed. fileSize: \(self.fileBuffer?.fileSize ?? -99), totalRowCount: \(self.totalRowCount)")
            
            newBuffer.$isDirty
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
            newBuffer.$changedBytes
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
            
            self.fileMetadata.size = newBuffer.fileSize
            // await calculateAndUpdateChecksums()
            
        } catch let error as FileBufferError {
            handleFileBufferError(error)
            self.fileBuffer = nil
            calculateVisibleRows()
            print("[ViewModel] loadFile: CATCH FileBufferError. errorMessage: \(self.errorMessage ?? "nil"), totalRowCount: \(self.totalRowCount)")
        } catch {
            self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            self.fileBuffer = nil
            calculateVisibleRows()
            print("[ViewModel] loadFile: CATCH general error. errorMessage: \(self.errorMessage ?? "nil"), totalRowCount: \(self.totalRowCount)")
        }
        
        self.isLoading = false
        print("[ViewModel] loadFile: END. isLoading: \(self.isLoading), fileBuffer is nil: \(self.fileBuffer == nil), totalRowCount: \(self.totalRowCount), errorMessage: \(self.errorMessage ?? "nil")")
    }
    
    func saveFile() async {
        guard let buffer = fileBuffer, buffer.isDirty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await buffer.save()
            undoManager.removeAllActions()
            self.fileMetadata.size = buffer.fileSize
            await calculateAndUpdateChecksums()
        } catch let error as FileBufferError {
            handleFileBufferError(error)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func resetEditorState() {
        print("[ViewModel] resetEditorState called.")
        if let currentBuffer = fileBuffer {
            print("[ViewModel] resetEditorState: Closing existing fileBuffer.")
            try? currentBuffer.close()
        }
        
        self.fileBuffer = nil
        self.selectedOffset = nil
        self.editingOffset = nil
        self.editText = ""
        self.searchQuery = ""
        self.searchResults = []
        self.currentSearchResultIndex = nil
        self.isExtractingStrings = false
        self.extractedStrings = []
        self.undoManager.removeAllActions()
        self.cancellables.forEach { $0.cancel() }
        self.cancellables.removeAll()
        self.fileMetadata = FileMetadata()
        calculateVisibleRows()
        print("[ViewModel] resetEditorState: State reset. totalRowCount: \(self.totalRowCount)")
    }
    
    private func handleFileBufferError(_ error: FileBufferError) {
        switch error {
        case .fileOpenFailed: errorMessage = "Failed to open file."
        case .mmapFailed: errorMessage = "Failed to memory map file. It might be too large or corrupted."
        case .unmapFailed: errorMessage = "Failed to unmap file."
        case .readOnlyViolation: errorMessage = "File is read-only and cannot be modified here."
        case .outOfBounds: errorMessage = "Attempted to access data out of file bounds."
        case .writeFailed: errorMessage = "Failed to write changes to disk."
        }
    }
    
    // MARK: - Byte Access and Modification
    func byteAt(offset: Int) -> UInt8? {
        fileBuffer?.byte(at: offset)
    }
    
    func isByteChanged(offset: Int) -> Bool {
        fileBuffer?.changedBytes[offset] != nil
    }
    
    // MARK: - Editing Logic
    func startEditing(offset: Int, isHex: Bool) {
        self.editingOffset = offset
        self.isEditingHex = isHex
        if let byte = byteAt(offset: offset) {
            self.editText = isHex ? String(format: "%02X", byte) : (isprint(Int32(byte)) != 0 ? String(UnicodeScalar(byte)) : ".")
        } else {
            self.editText = isHex ? "00" : ""
        }
        self.selectedOffset = offset
    }
    
    func cancelEditing() {
        self.editingOffset = nil
        self.editText = ""
    }
    
    func commitEditing() {
        guard let editingOffset = editingOffset, let buffer = fileBuffer else {
            cancelEditing()
            return
        }
        
        let originalCommittedOffset = editingOffset
        
        do {
            if isEditingHex {
                guard let newValue = UInt8(editText, radix: 16), editText.count > 0, editText.count <= 2 else {
                    errorMessage = "Invalid hex input: \(editText)"
                    cancelEditing()
                    return
                }
                try buffer.updateByte(at: editingOffset, newValue: newValue, undoManager: self.undoManager)
            } else {
                guard let char = editText.first, let asciiValue = char.asciiValue, editText.count == 1 else {
                    errorMessage = "Invalid ASCII input: \(editText)"
                    cancelEditing()
                    return
                }
                try buffer.updateByte(at: editingOffset, newValue: asciiValue, undoManager: self.undoManager)
            }
            // if originalCommittedOffset < buffer.fileSize - 1 {
            //     self.selectedOffset = originalCommittedOffset + 1
            // }
            
        } catch let error as FileBufferError {
            handleFileBufferError(error)
        } catch {
            errorMessage = "Error updating byte: \(error.localizedDescription)"
        }
        
        self.editingOffset = nil
        self.editText = ""
        objectWillChange.send()
    }
    
    // MARK: - View Configuration
    func formatOffset(_ offset: Int) -> String {
        let formatString = offsetDisplayBase == 16 ? "%08X" : "%08d"
        return String(format: formatString, offset)
    }
    

    func calculateVisibleRows() {
        guard let buffer = fileBuffer, buffer.fileSize > 0 else {
            totalRowCount = 0
            // print("[ViewModel] calculateVisibleRows: buffer is nil or filesize is 0. totalRowCount = 0")
            return
        }
        totalRowCount = (buffer.fileSize + bytesPerRow - 1) / bytesPerRow
        // print("[ViewModel] calculateVisibleRows: fileSize=\(buffer.fileSize), bytesPerRow=\(bytesPerRow), totalRowCount=\(totalRowCount)")
    }
    
    // MARK: - Search and Jump
    func jumpToOffset(input: String) {
        guard let buffer = fileBuffer else { return }
        let cleanedInput = input.lowercased().replacingOccurrences(of: "0x", with: "")
        
        var targetOffset: Int?
        if let decOffset = Int(cleanedInput, radix: 10) {
            targetOffset = decOffset
        } else if let hexOffset = Int(cleanedInput, radix: 16) {
            targetOffset = hexOffset
        }
        
        guard let offset = targetOffset, offset >= 0, offset < buffer.fileSize else {
            errorMessage = "Invalid offset: \(input). Must be within 0 and \(buffer.fileSize - 1)."
            return
        }
        selectedOffset = offset
        errorMessage = nil
    }
    
    func search(query: String, searchHex: Bool) async {
        guard let buffer = fileBuffer, !query.isEmpty else {
            self.searchResults = []
            self.currentSearchResultIndex = nil
            return
        }
        
        isSearching = true
        self.searchResults = []
        self.currentSearchResultIndex = nil
        self.errorMessage = nil
        defer { isSearching = false }
        
        var needles: [UInt8] = []
        if searchHex {
            let hexComponents = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            for component in hexComponents {
                if component.isEmpty { continue }
                if let byte = UInt8(component, radix: 16) {
                    needles.append(byte)
                } else {
                    errorMessage = "Invalid hex sequence in search query: \(component)"
                    return
                }
            }
        } else {
            needles = [UInt8](query.utf8)
        }
        
        guard !needles.isEmpty else {
            errorMessage = "Empty search query after parsing."
            return
        }
        
        var foundOffsets: [Int] = []
        let searchTask = Task.detached(priority: .userInitiated) { [weak buffer, needles] () -> [Int] in
            guard let strongBuffer = buffer else { return [] }
            var localFoundOffsets: [Int] = []
            if strongBuffer.fileSize < needles.count { return [] }
            
            for i in 0...(strongBuffer.fileSize - needles.count) {
                var match = true
                for j in 0..<needles.count {
                    if strongBuffer.byte(at: i + j) != needles[j] {
                        match = false
                        break
                    }
                }
                if match {
                    localFoundOffsets.append(i)
                }
                if Task.isCancelled { break }
            }
            return localFoundOffsets
        }
        
        foundOffsets = await searchTask.value
        
        self.searchResults = foundOffsets
        if !foundOffsets.isEmpty {
            self.currentSearchResultIndex = 0
            self.selectedOffset = foundOffsets[0]
        } else {
            self.errorMessage = "Search query '\(query)' not found."
        }
    }
    
    func nextSearchResult() {
        guard !searchResults.isEmpty, var currentIndex = currentSearchResultIndex else { return }
        currentIndex = (currentIndex + 1) % searchResults.count
        currentSearchResultIndex = currentIndex
        selectedOffset = searchResults[currentIndex]
    }
    
    func previousSearchResult() {
        guard !searchResults.isEmpty, var currentIndex = currentSearchResultIndex else { return }
        currentIndex = (currentIndex - 1 + searchResults.count) % searchResults.count
        currentSearchResultIndex = currentIndex
        selectedOffset = searchResults[currentIndex]
    }
    
    // MARK: - Metadata Calculation
    func calculateAndUpdateChecksums() async {
        guard let buffer = fileBuffer else { return }
        guard !self.fileMetadata.isCalculatingChecksums else { return }
        
        self.fileMetadata.isCalculatingChecksums = true
        self.fileMetadata.md5 = nil
        self.fileMetadata.sha1 = nil
        self.fileMetadata.sha256 = nil
        
        async let md5Task = buffer.calculateChecksum(type: .md5)
        async let sha1Task = buffer.calculateChecksum(type: .sha1)
        async let sha256Task = buffer.calculateChecksum(type: .sha256)
        
        let (md5, sha1, sha256) = await (md5Task, sha1Task, sha256Task)
        
        self.fileMetadata.md5 = md5
        self.fileMetadata.sha1 = sha1
        self.fileMetadata.sha256 = sha256
        self.fileMetadata.isCalculatingChecksums = false
    }
    
    // MARK: - String Extraction
    func extractStrings() async {
        guard let buffer = fileBuffer, buffer.fileSize > 0 else {
            self.extractedStrings = []
            return
        }
        
        isExtractingStrings = true
        defer { isExtractingStrings = false }
        
        let extractionTask = Task.detached(priority: .userInitiated) { [weak buffer, minLength = self.minStringLength] () -> [ExtractedStringInfo] in

            guard let strongBuffer = buffer else { return [] }
            
            var localResults: [ExtractedStringInfo] = []
            var currentStringBytes: [UInt8] = []
            var currentStringOffset: Int = 0
            
            for offset in 0..<strongBuffer.fileSize {
                guard let byte = strongBuffer.byte(at: offset) else { continue }
                
                if byte >= 32 && byte <= 126 {
                    if currentStringBytes.isEmpty {
                        currentStringOffset = offset
                    }
                    currentStringBytes.append(byte)
                } else {
                    if currentStringBytes.count >= minLength {
                        if let str = String(bytes: currentStringBytes, encoding: .ascii) {
                            localResults.append(ExtractedStringInfo(offset: currentStringOffset, string: str))
                        }
                    }
                    currentStringBytes.removeAll()
                }
                if Task.isCancelled { break }
            }
            if currentStringBytes.count >= minLength {
                if let str = String(bytes: currentStringBytes, encoding: .ascii) {
                    localResults.append(ExtractedStringInfo(offset: currentStringOffset, string: str))
                }
            }
            return localResults
        }
        
        self.extractedStrings = await extractionTask.value
    }
    
    public func refreshStateAfterExternalBufferSet() {
        print("[ViewModel \(self.fileBuffer?.url.lastPathComponent ?? "NoFile")] refreshStateAfterExternalBufferSet called.")
        // Ensure isLoading is false if this path is taken.
        self.isLoading = false
        
        if let buffer = self.fileBuffer, buffer.fileSize > 0 {
            // self.selectedOffset = 0
        } else {
        }
    
        calculateVisibleRows()
        print("[ViewModel \(self.fileBuffer?.url.lastPathComponent ?? "NoFile")] refreshStateAfterExternalBufferSet done. totalRowCount: \(self.totalRowCount)")
    }
}
    

// MARK: - Supporting Structs (already defined but ensure they are accessible)
struct FileMetadata: Equatable {
    var size: Int = 0
    var md5: String?
    var sha1: String?
    var sha256: String?
    var isCalculatingChecksums: Bool = false

    init(size: Int = 0, md5: String? = nil, sha1: String? = nil, sha256: String? = nil, isCalculatingChecksums: Bool = false) {
        self.size = size
        self.md5 = md5
        self.sha1 = sha1
        self.sha256 = sha256
        self.isCalculatingChecksums = isCalculatingChecksums
    }
}

struct ExtractedStringInfo: Identifiable, Hashable {
    let id = UUID()
    let offset: Int
    let string: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExtractedStringInfo, rhs: ExtractedStringInfo) -> Bool {
        lhs.id == rhs.id
    }
}
