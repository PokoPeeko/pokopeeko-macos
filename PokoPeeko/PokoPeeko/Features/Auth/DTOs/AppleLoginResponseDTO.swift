import Foundation

struct AppleLoginResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Data

  struct Data: Decodable {
    let sessionId: String
    let needsProfileSetup: Bool
  }
}
