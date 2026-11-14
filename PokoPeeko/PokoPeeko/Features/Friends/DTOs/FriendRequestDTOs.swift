import Foundation

struct ReceivedFriendRequestsResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Payload
  struct Payload: Decodable { let friendRequests: [Request] }
  struct Request: Decodable {
    let id: String
    let requester: FriendProfileDTO
  }
}

struct SentFriendRequestsResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Payload
  struct Payload: Decodable { let friendRequests: [Request] }
  struct Request: Decodable {
    let id: String
    let addressee: FriendProfileDTO
  }
}

struct SendFriendRequestResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Payload
  struct Payload: Decodable { let friendRequestId: String }
}

struct FriendActionResponseDTO: Decodable {
  let success: Bool
  let message: String
  // 동작 응답의 data는 null이므로 사용하지 않는다.
}
