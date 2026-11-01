import KBSyncCore
import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel
    @Binding var showIcon: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("kbsync").font(.headline)
                    Text(model.statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Toggle("Sync keyboard with screen", isOn: $model.isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if model.agentRunning {
                note("The kbsync command-line agent is running too. Run `kbsync uninstall` so they don't both set the keyboard.")
            }
            if let problem = model.problem {
                note(problem)
            }

            Divider()

            levelSlider("Keyboard at brightest screen", value: $model.maxPercent)
            levelSlider("Keyboard at dimmest screen", value: $model.minPercent)

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            VStack(alignment: .leading, spacing: 2) {
                Button("Hide menu bar icon") { showIcon = false }
                    .buttonStyle(.link)
                Text("Open kbsync again to bring it back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("v\(version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit kbsync") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear { model.refresh() }
    }

    private func levelSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            // A stepped slider draws a tick for every step, so round instead.
            Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0.rounded() }), in: 0...100)
                .disabled(!model.isOn)
        }
    }

    private func note(_ text: String) -> some View {
        Text(.init(text))
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}
