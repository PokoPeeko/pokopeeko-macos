import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginController {
  private(set) var status = SMAppService.Status.notRegistered
  private(set) var errorMessage: String?
  private(set) var isUpdating = false
  private let service = SMAppService.mainApp

  init() { refresh() }

  var isRegistered: Bool { status == .enabled || status == .requiresApproval }
  var requiresApproval: Bool { status == .requiresApproval }

  func refresh() { status = service.status }

  func setEnabled(_ enabled: Bool) {
    guard !isUpdating else { return }
    refresh()
    guard enabled != isRegistered else { return }
    isUpdating = true
    errorMessage = nil
    defer { refresh(); isUpdating = false }
    do {
      if enabled { try service.register() }
      else { try service.unregister() }
    } catch {
      errorMessage = "자동 실행 설정을 변경하지 못했어요. \(error.localizedDescription)"
    }
  }

  func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
