import Cocoa

final class SizeCellView: NSTableCellView {
    func setup(with xcodeEntry: XcodeFileEntry) {
        if let textField = textField, let sizeInBytes = xcodeEntry.size.numberOfBytes {
            textField.placeholderString = ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
            textField.sizeToFit()
        }
    }
}
