import SwiftUI
import UniformTypeIdentifiers

struct AppsView: View {
  @Environment(MainViewModel.self) private var model
  @State private var search = ""
  @State private var sortByName = false
  @State private var showBlockedApps = false
  @State private var isAddingApp = false
  @State private var isDeletingApp = false
  @State private var pendingDeletion: DetectedApp?

  private var sourceApps: [DetectedApp] { showBlockedApps ? model.blockedApps : model.apps }

  private var apps: [DetectedApp] {
    let filtered = sourceApps.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    return sortByName ? filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : filtered
  }

  var body: some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("앱 목록").font(.headline)
          Spacer()
          Picker("정렬", selection: $sortByName) {
            Text("등록순").tag(false)
            Text("이름순").tag(true)
          }
          .labelsHidden().frame(width: 140)
          Button { isAddingApp = true } label: {
            Label("앱 직접 추가", systemImage: "plus")
          }
        }
        Picker("앱 목록 구분", selection: $showBlockedApps) {
          Text("앱 목록").tag(false)
          Text("차단한 앱 (\(model.blockedApps.count))").tag(true)
        }
        .pickerStyle(.segmented)
        if let error = model.appCatalog.storageError {
          Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
        Label(model.appCatalog.isMonitoring ? "실행 중인 앱을 자동으로 감지하고 있어요" : "앱 감지를 시작하고 있어요",
              systemImage: "dot.radiowaves.left.and.right")
          .font(.caption).foregroundStyle(.secondary)
        TextField("앱 검색", text: $search).textFieldStyle(.roundedBorder)
          .accessibilityLabel("앱 이름 검색")
        if sourceApps.isEmpty && showBlockedApps {
          ContentUnavailableView("차단한 앱이 없어요", systemImage: "hand.raised",
                                 description: Text("차단한 앱은 이곳에 모이며 자동으로 다시 등록되지 않아요."))
        } else if sourceApps.isEmpty {
          ContentUnavailableView {
            Label("등록된 앱이 없어요", systemImage: "square.stack.3d.up")
          } description: {
            Text("앱을 실행하거나 전환하면 자동으로 등록됩니다.\n감지되지 않는 앱은 직접 추가할 수 있어요.")
          } actions: {
            Button("앱 직접 추가") { isAddingApp = true }
          }
        } else if apps.isEmpty {
          ContentUnavailableView.search(text: search)
        } else {
          HStack {
            Text("애플리케이션")
            Spacer()
            if !showBlockedApps {
              Text("차단").frame(width: 64)
              Text("노출").frame(width: 48)
              Color.clear.frame(width: 30, height: 1)
            }
          }
          .font(.caption).foregroundStyle(.secondary)
          ForEach(apps) { app in
            HStack(spacing: 12) {
              AppIconView(bundleIdentifier: app.id, applicationPath: app.applicationPath, size: 40)
              VStack(alignment: .leading, spacing: 4) {
                Text(app.name).fontWeight(.medium)
                Text(app.id).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if app.isManuallyAdded { Text("직접 추가").font(.caption2).foregroundStyle(.secondary) }
              }
              Spacer(minLength: 4)
              if showBlockedApps {
                Button("차단 해제") {
                  model.appCatalog.updateApp(app.id, detection: true)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(app.name) 차단 해제")
                .help("자동 감지를 다시 허용하고 앱 목록으로 이동")
              } else {
                Button("차단") {
                  model.appCatalog.updateApp(app.id, detection: false)
                }
                .buttonStyle(.bordered).tint(.secondary).frame(width: 64)
                .accessibilityLabel("\(app.name) 차단")
                .help("차단 목록으로 이동하고 자동 재등록을 막습니다")
                Toggle("\(app.name) 노출", isOn: Binding(
                  get: { app.isVisible },
                  set: { model.appCatalog.updateApp(app.id, visible: $0) }
                ))
                .labelsHidden().frame(width: 48)
                Button {
                  pendingDeletion = app
                  isDeletingApp = true
                } label: {
                  Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless).frame(width: 30)
                .help("목록에서 삭제").accessibilityLabel("\(app.name) 목록에서 삭제")
              }
            }
            .toggleStyle(.switch).controlSize(.small)
            Divider()
          }
        }
        VStack(alignment: .leading, spacing: 5) {
          Text("차단: 차단 목록으로 이동하며 자동 재등록 방지 · 노출 끄기: 감지는 유지하고 앱 이름 공유를 숨김")
          Text("삭제는 목록에서만 제거합니다. 차단하지 않은 앱은 다시 감지되면 재등록될 수 있어요.")
          Text("목록·차단·노출 설정은 이 Mac에 저장됩니다. 로그인 후 실시간 연결되면 현재 앱을 공유합니다.")
        }
        .font(.caption).foregroundStyle(.secondary)
      }
    }
    .sheet(isPresented: $isAddingApp) { AddAppSheet() }
    .alert("목록에서 삭제할까요?", isPresented: $isDeletingApp, presenting: pendingDeletion) { app in
      Button("삭제", role: .destructive) { model.appCatalog.removeApp(app.id) }
      Button("취소", role: .cancel) { }
    } message: { app in
      Text("\(app.name)을 목록에서만 지웁니다. 삭제는 차단이 아니므로 다시 실행하거나 전환하면 재등록될 수 있어요. 설치된 앱에는 영향을 주지 않습니다.")
    }
  }
}

private struct AddAppSheet: View {
  @Environment(MainViewModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var bundleID = ""
  @State private var isChoosingFile = false
  @State private var errorMessage: String?
  @State private var selectedAppPath: String?
  @State private var selectedBundleID: String?

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var trimmedID: String { bundleID.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var isBlocked: Bool { model.blockedApps.contains { $0.id == trimmedID } }
  private var isDuplicate: Bool { model.apps.contains { $0.id == trimmedID } || isBlocked }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("앱 직접 추가").font(.title2.bold())
      Text("자동 감지되지 않는 앱의 파일을 선택하거나 정보를 입력해주세요.")
        .foregroundStyle(.secondary)
      Button { isChoosingFile = true } label: {
        Label(".app 파일 선택", systemImage: "folder")
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("앱 이름").font(.caption).foregroundStyle(.secondary)
        TextField("앱 이름", text: $name)
        Text("번들 ID").font(.caption).foregroundStyle(.secondary)
        TextField("예: com.example.app", text: $bundleID)
      }
      .textFieldStyle(.roundedBorder)
      if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
      if isBlocked {
        Text("차단된 앱입니다. 차단한 앱 탭에서 먼저 차단을 해제해주세요.")
          .font(.caption).foregroundStyle(.red)
      } else if isDuplicate {
        Text("이미 목록에 있는 앱입니다.").font(.caption).foregroundStyle(.red)
      }
      Text("앱 정보는 이 Mac의 목록에 저장되며, 앱을 실행하거나 서버에 전송하지 않습니다.")
        .font(.caption).foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("목록에 추가") {
          let app = DetectedApp(id: trimmedID, name: trimmedName,
                                applicationPath: selectedBundleID == trimmedID ? selectedAppPath : nil)
          if model.appCatalog.addApp(app) {
            dismiss()
          } else {
            errorMessage = "이미 등록되었거나 차단된 앱입니다. 목록을 확인해주세요."
          }
        }
        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        .disabled(trimmedName.isEmpty || trimmedID.isEmpty || isDuplicate)
      }
    }
    .padding(24).frame(width: 440)
    .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.applicationBundle], allowsMultipleSelection: false) { result in
      do {
        guard let url = try result.get().first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else {
          errorMessage = "앱 정보를 읽을 수 없어요. 이름과 번들 ID를 직접 입력해주세요."
          return
        }
        name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
          ?? url.deletingPathExtension().lastPathComponent
        selectedAppPath = url.path
        selectedBundleID = identifier
        bundleID = identifier
        errorMessage = nil
      } catch {
        errorMessage = "파일을 열지 못했어요. 다시 선택하거나 정보를 직접 입력해주세요."
      }
    }
  }
}
