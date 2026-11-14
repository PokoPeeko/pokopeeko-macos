import Foundation

struct ErrorResponseDTO: Decodable {
  let message: String?

  private enum CodingKeys: String, CodingKey { case message }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let text = try? container.decode(String.self, forKey: .message) {
      message = text
    } else if let messages = try? container.decode([String].self, forKey: .message) {
      message = messages.joined(separator: "\n")
    } else {
      message = nil
    }
  }
}
