//

import Foundation

struct AppleLoginResponseDTO: Decodable {
  let message: String
  let data: Data

  struct Data: Decodable {
    let sessionId: String
  }
}

struct ErrorResponseDTO: Decodable {
  let success: Bool
  let message: String
}
