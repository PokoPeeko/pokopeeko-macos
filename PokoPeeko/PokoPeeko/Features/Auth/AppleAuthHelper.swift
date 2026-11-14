import Foundation
import CryptoKit
import Security

enum AppleAuthHelper {
  static func randomNonceString(length: Int = 32) throws -> String {
    guard length > 0 else { throw NonceError.generationFailed }
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._".utf8)
    let upperBound = 256 - 256 % charset.count
    var nonce: [UInt8] = []
    while nonce.count < length {
      var bytes = [UInt8](repeating: 0, count: 16)
      guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
        throw NonceError.generationFailed
      }
      for byte in bytes where Int(byte) < upperBound {
        nonce.append(charset[Int(byte) % charset.count])
        if nonce.count == length { break }
      }
    }
    return String(decoding: nonce, as: UTF8.self)
  }

  static func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  enum NonceError: LocalizedError {
    case generationFailed
    var errorDescription: String? { "로그인 요청을 준비하지 못했어요. 다시 시도해주세요." }
  }
}
