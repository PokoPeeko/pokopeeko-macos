import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProfileImageProcessor {
  /// 메타데이터와 파일 경로 대신, 방향을 반영한 최대 1024px PNG만 업로드한다.
  static func pngData(from data: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024
          ] as CFDictionary) else { throw ImageError.invalidImage }

    let output = NSMutableData()

    guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
      throw ImageError.invalidImage
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ImageError.invalidImage }
    return output as Data
  }

  enum ImageError: LocalizedError {
    case invalidImage
    var errorDescription: String? { "이미지를 읽을 수 없어요. 다른 이미지 파일을 선택해주세요." }
  }
}
