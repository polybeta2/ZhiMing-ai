#if canImport(SwiftUI)
import SwiftUI

/// 外观设置：强调色五选一 + 深色模式（跟随/浅/深）
struct AppearanceSettingsView: View {
    @AppStorage(AppearanceSettings.accentKey) private var accentIndex = 0
    @AppStorage(AppearanceSettings.schemeKey) private var schemeIndex = 0

    var body: some View {
        Form {
            Section("强调色") {
                HStack(spacing: AppTheme.spacing[2]) {
                    ForEach(AppTheme.accentPresets.indices, id: \.self) { index in
                        Circle()
                            .fill(AppTheme.accentPresets[index])
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .opacity(accentIndex == index ? 1 : 0)
                            )
                            .onTapGesture { accentIndex = index }
                    }
                    Spacer()
                }
                .padding(.vertical, AppTheme.spacing[1])
            }

            Section("深色模式") {
                Picker("外观", selection: $schemeIndex) {
                    Text("跟随系统").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
