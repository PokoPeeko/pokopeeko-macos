import Foundation

/// JSON이 아닌 multipart/form-data로 전송한다. 이미지는 선택적인 PNG 파일 바이트다.
struct ProfileSetupRequestDTO {
  let displayName: String?
  let profileImage: Data?

  func multipartBody(boundary: String) -> Data {
    var body = Data()
    func append(_ text: String) { body.append(contentsOf: text.utf8) }
    if let displayName {
      append("--\(boundary)\r\n")
      append("Content-Disposition: form-data; name=\"displayName\"\r\n\r\n")
      append("\(displayName)\r\n")
    }
    if let profileImage {
      append("--\(boundary)\r\n")
      append("Content-Disposition: form-data; name=\"profile_image\"; filename=\"profile.png\"\r\n")
      append("Content-Type: image/png\r\n\r\n")
      body.append(profileImage)
      append("\r\n")
    }
    append("--\(boundary)--\r\n")
    return body
  }
}
