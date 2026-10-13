import SwiftUI

/// A safe place to get used to the keyboard before using it everywhere (US-007).
///
/// This types into its own buffer using the same shared surface the extension
/// uses, so the resizing behaviour on show here is the real thing.
struct PracticePadView: View {

    @EnvironmentObject private var store: SharedStore
    @StateObject private var buffer = BufferTextSink()
    @StateObject private var controller = PredictionController()
    @StateObject private var composer = TextComposer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pad
                Spacer(minLength: 0)
                KeyboardSurface(store: store, controller: controller, composer: composer, sink: buffer)
            }
            .background(Theme.surfaceBase)
            .navigationTitle("Practice")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        buffer.text = ""
                        controller.refresh(context: "", isSecure: false)
                    }
                    .disabled(buffer.text.isEmpty)
                }
            }
        }
    }

    private var pad: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type freely — watch the keys grow and shrink.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            HStack(alignment: .bottom, spacing: 1) {
                Text(buffer.text.isEmpty ? "Start typing…" : buffer.text)
                    .font(.system(size: 19))
                    .foregroundStyle(buffer.text.isEmpty ? Theme.textMuted : Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("practicePadText")
                if !buffer.text.isEmpty {
                    Rectangle()
                        .fill(Theme.brand)
                        .frame(width: 2, height: 21)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.ruleHairline, lineWidth: 1)
            )

            if !controller.isEngineAvailable {
                Text("The bundled word list didn't load, so the keys won't resize.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.negative)
            }
        }
        .padding(16)
    }
}
