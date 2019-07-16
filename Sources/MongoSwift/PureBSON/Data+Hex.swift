import Foundation

extension Data {
    internal static var hexDigits = "01234567890abcdef"
    internal static var byteMap: [UInt8] = [
      0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
      0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
      0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // HIJKLMNO
    ]

    internal var hex: String {
        return self.reduce("") { $0 + String(format: "%02x", $1) }
    }

    // from https://stackoverflow.com/a/52600783/11655924
    internal init?(hex: String) {
        guard hex.count % 2 == 0 else {
            return nil
        }

        guard (hex.lowercased().allSatisfy { Data.hexDigits.contains($0) }) else {
            return nil
        }

        let chars = Array(hex.lowercased().utf8)
        var data = Data(capacity: chars.count / 2)

        for i in stride(from: 0, to: chars.count, by: 2) {
            let index1 = Int(chars[i] & 0x1F ^ 0x10)
            let index2 = Int(chars[i + 1] & 0x1F ^ 0x10)
            data.append(Data.byteMap[index1] << 4 | Data.byteMap[index2])
        }

        self = data
    }
}
