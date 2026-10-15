import AppKit
import SwiftUI

struct WellbeingPageHeader: View {
    let title: String
    let onBack: () -> Void
    var body: some View {
        HStack {
            Button(action: onBack) { Label("返回专注", systemImage: "chevron.left") }
                .buttonStyle(.plain).font(.system(size: 15, weight: .medium))
                .accessibilityIdentifier("wellbeing.back")
            Spacer()
        }.frame(height: 36)
            .overlay { Text(title).font(.system(size: 20, weight: .bold)).allowsHitTesting(false) }
            .padding(.horizontal, 36).padding(.top, 36)
    }
}

private enum JournalMood: String, CaseIterable, Identifiable {
    case calm = "平静", relaxed = "轻松", neutral = "一般", sad = "低落", irritated = "烦躁"
    var id: String { rawValue }
    var emoji: String {
        switch self { case .calm: return "🙂"; case .relaxed: return "😊"; case .neutral: return "😐"; case .sad: return "😟"; case .irritated: return "😤" }
    }
    var asset: String {
        switch self { case .calm: return "mood-calm"; case .relaxed: return "mood-relaxed"; case .neutral: return "mood-neutral"; case .sad: return "mood-sad"; case .irritated: return "mood-irritated" }
    }
}

struct MoodJournalPage: View {
    @ObservedObject var wellbeing: WellbeingStore
    let onBack: () -> Void
    let onHistory: () -> Void
    @State private var selected: JournalMood?
    @State private var note = ""
    @State private var saved = false
    private var canSave: Bool { selected != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        VStack(spacing: 0) {
            WellbeingPageHeader(title: "心情记录", onBack: onBack)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("记录此刻的心情", systemImage: "heart.fill")
                            .font(.system(size: 24, weight: .bold))
                            .labelStyle(MoodHeadingStyle())
                        Text(saved ? "已记下，留一点时间给自己。" : "把此刻的感受记下来，和自己待一会儿。")
                            .font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                    }
                    Spacer()
                }.frame(height: 80)
                HStack(spacing: 24) {
                    ForEach(JournalMood.allCases) { mood in
                        Button {
                            selected = selected == mood ? nil : mood
                            saved = false
                        } label: {
                            VStack(spacing: 5) {
                                Image(nsImage: Self.image(mood.asset)).resizable().scaledToFit()
                                    .frame(width: 76, height: 76).padding(5)
                                    .overlay { Circle().stroke(selected == mood ? FocusTheme.accent : .clear, lineWidth: 1.5) }
                                Text(mood.rawValue).font(.system(size: 15, weight: .medium))
                                    .frame(maxWidth: .infinity).frame(height: 28)
                                    .background(selected == mood ? FocusTheme.accent.opacity(0.12) : .clear, in: Capsule())
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(mood.rawValue)
                            .accessibilityAddTraits(selected == mood ? .isSelected : [])
                            .accessibilityIdentifier("mood.\(mood.asset)")
                    }
                }.padding(.top, 4)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.85))
                    RoundedRectangle(cornerRadius: 16).stroke(FocusTheme.accent.opacity(0.15), lineWidth: 1)
                    if note.isEmpty {
                        Text("想说的话，留在这里。（选填）").font(.system(size: 14))
                            .foregroundStyle(FocusTheme.secondary.opacity(0.8)).padding(.leading, 17).padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                    MoodNoteEditor(text: $note).padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 30)
                    Text("\(note.count)/100").font(.system(size: 12)).monospacedDigit()
                        .foregroundStyle(FocusTheme.secondary).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(15).allowsHitTesting(false)
                }.frame(height: 104).padding(.top, 16)
                HStack {
                    Text(saved ? "已保存到这台 Mac。" : "也可以只写文字，不选心情。")
                        .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
                    Spacer()
                    Button {
                        guard canSave else { return }
                        wellbeing.recordMood(emoji: selected?.emoji ?? "📝", name: selected?.rawValue ?? "随手记", note: note)
                        selected = nil; note = ""; saved = true
                    } label: { Text("保存记录") }
                        .buttonStyle(SettingsActionStyle(primary: true))
                        .disabled(!canSave).opacity(canSave ? 1 : 0.5).accessibilityIdentifier("mood.save")
                }.padding(.top, 16)
                Spacer(minLength: 12)
            }.padding(.horizontal, 56).padding(.top, 12)
                .onChange(of: note) { value in if !value.isEmpty { saved = false } }
            HStack(spacing: 18) {
                shelfIcon("text.alignleft")
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日记录").font(.system(size: 14, weight: .medium))
                    Text("\(wellbeing.moodCountToday()) 次").font(.system(size: 25, weight: .semibold, design: .rounded))
                }
                Spacer()
                Divider().frame(height: 38)
                Button(action: onHistory) { Label("查看记录", systemImage: "chevron.right").labelStyle(TrailingWellbeingLabel()) }
                    .buttonStyle(.plain).font(.system(size: 15, weight: .medium)).accessibilityIdentifier("mood.history")
            }.padding(.horizontal, 56).frame(height: 90).background(FocusTheme.shelf.opacity(0.8))
        }.foregroundStyle(FocusTheme.ink).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FocusTheme.background).ignoresSafeArea()
    }
    private static func image(_ name: String) -> NSImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) else { return NSImage() }
        return image
    }
}

struct MeditationPage: View {
    @ObservedObject var wellbeing: WellbeingStore
    let onBack: () -> Void
    let onHistory: () -> Void
    @State private var showsReminders = false
    @State private var reminderTime = Date()
    private var reminderSummary: String {
        wellbeing.meditationTimes.isEmpty ? "尚未设置" : wellbeing.meditationTimes.map { String(format: "%02d:%02d", $0.hour, $0.minute) }.joined(separator: " · ")
    }
    var body: some View {
        VStack(spacing: 0) {
            WellbeingPageHeader(title: "1 分钟冥想", onBack: onBack)
            if showsReminders {
                reminders.padding(.horizontal, 64).padding(.top, 26)
                Spacer(minLength: 16)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 10) {
                        BreathingFlowerView(isActive: wellbeing.isMeditating, sessionID: wellbeing.meditationSessionID, largeStyle: true)
                        if let remaining = wellbeing.meditationRemainingText {
                            Text(remaining).font(.system(size: 15, weight: .medium)).monospacedDigit()
                                .foregroundStyle(FocusTheme.secondary)
                        }
                        Button { wellbeing.startMeditation() } label: {
                            Text(wellbeing.isMeditating ? "重新开始" : "开始").frame(width: 160, height: 40)
                        }.buttonStyle(FocusPillStyle(fill: FocusTheme.accent, ink: .white, fontSize: 17))
                            .accessibilityIdentifier("meditation.start").padding(.top, 14)
                        Spacer(minLength: 18)
                    }.frame(maxWidth: .infinity).padding(.top, 10)
                    FocusCat(size: 108).padding(.trailing, 36).offset(y: 12).accessibilityHidden(true)
                }.clipped()
            }
            HStack(spacing: 14) {
                shelfIcon("leaf.fill", color: Color(red: 0.43, green: 0.57, blue: 0.32))
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日完成").font(.system(size: 14, weight: .medium))
                    Text("\(wellbeing.meditationCountToday) 次").font(.system(size: 25, weight: .semibold, design: .rounded))
                }
                Spacer(minLength: 12)
                Divider().frame(height: 38)
                Button(action: onHistory) { Label("查看记录", systemImage: "chevron.right").labelStyle(TrailingWellbeingLabel()) }
                    .buttonStyle(.plain).font(.system(size: 14, weight: .medium)).accessibilityIdentifier("meditation.history")
                Spacer(minLength: 12)
                Divider().frame(height: 38)
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { showsReminders.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        shelfIcon("clock", size: 42)
                        VStack(alignment: .leading, spacing: 7) {
                            Label(showsReminders ? "返回呼吸" : "每日提醒", systemImage: showsReminders ? "chevron.up" : "chevron.right")
                                .labelStyle(TrailingWellbeingLabel()).font(.system(size: 14, weight: .medium))
                            Text(reminderSummary).font(.system(size: 12)).foregroundStyle(FocusTheme.secondary).lineLimit(1)
                                .frame(width: 156, alignment: .leading).truncationMode(.tail)
                        }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("meditation.reminders")
            }.padding(.horizontal, 42).frame(height: 98).background(FocusTheme.shelf.opacity(0.8))
        }.foregroundStyle(FocusTheme.ink).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FocusTheme.background).ignoresSafeArea()
    }
    private var reminders: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("每日提醒").font(.system(size: 25, weight: .bold))
                    Text("在这些时间，提醒你停下来休息。")
                        .font(.system(size: 14)).foregroundStyle(FocusTheme.secondary)
                }
                Spacer()
                Button("完成") { withAnimation(.easeInOut(duration: 0.16)) { showsReminders = false } }
                    .buttonStyle(SettingsActionStyle(primary: true)).accessibilityIdentifier("meditation.reminders.done")
            }
            ScrollView {
                VStack(spacing: 0) {
                    if wellbeing.meditationTimes.isEmpty {
                        Text("还没有提醒，添加一个适合你的时间。")
                            .font(.system(size: 14)).foregroundStyle(FocusTheme.secondary).frame(height: 90)
                    }
                    ForEach(wellbeing.meditationTimes) { time in
                        HStack {
                            Text(time.displayText).font(.system(size: 18, weight: .medium)).monospacedDigit()
                            Spacer()
                            Button { wellbeing.removeMeditationTime(time) } label: {
                                Image(systemName: "minus.circle").font(.system(size: 20)).frame(width: 40, height: 44)
                            }.buttonStyle(.plain).foregroundStyle(FocusTheme.secondary)
                                .accessibilityLabel("移除 \(time.displayText) 提醒")
                        }.frame(height: 56)
                        Divider()
                    }
                }
            }.frame(maxHeight: 220)
            HStack(spacing: 16) {
                DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute).labelsHidden()
                    .frame(width: 140)
                    .accessibilityLabel("提醒时间")
                Button {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                    wellbeing.addMeditationTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
                } label: { Label("添加提醒", systemImage: "plus") }
                    .buttonStyle(SettingsActionStyle()).accessibilityIdentifier("meditation.reminders.add")
                Spacer()
            }
            Text(wellbeing.isMeditating ? "呼吸计时继续进行，修改提醒不会中断冥想。" : "提醒每天重复，关闭 App 后由系统通知提醒。")
                .font(.system(size: 12)).foregroundStyle(FocusTheme.secondary)
        }
    }
}

private struct TrailingWellbeingLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) { configuration.title; configuration.icon.font(.system(size: 11, weight: .semibold)) }
    }
}
private struct MoodHeadingStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 15) { configuration.icon.foregroundStyle(Color(red: 1, green: 0.50, blue: 0.47)); configuration.title }
    }
}
private func shelfIcon(_ name: String, color: Color = FocusTheme.accent, size: CGFloat = 52) -> some View {
    Image(systemName: name).font(.system(size: 23, weight: .medium)).foregroundStyle(color)
        .frame(width: size, height: size).background(color.opacity(0.12), in: Circle())
}

// Native input keeps Chinese IME composition intact, and only limits committed text.
private struct MoodNoteEditor: NSViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        let editor = NSTextView()
        editor.isRichText = false; editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 15)
        editor.textColor = NSColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        editor.insertionPointColor = .systemBlue
        editor.textContainerInset = NSSize(width: 4, height: 5)
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("心情文字，最多 100 字")
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = view.documentView as? NSTextView, !editor.hasMarkedText(), editor.string != text else { return }
        editor.string = text
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MoodNoteEditor
        init(_ parent: MoodNoteEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, !editor.hasMarkedText() else { return }
            if editor.string.count > 100 {
                let selection = editor.selectedRange()
                editor.string = String(editor.string.prefix(100))
                editor.setSelectedRange(NSRange(location: min(selection.location, editor.string.utf16.count), length: 0))
            }
            parent.text = editor.string
        }
    }
}
