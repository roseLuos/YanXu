import SwiftUI

struct UnifiedPlanningView: View {
    @Binding var showsTaskEditor: Bool

    var body: some View {
        GeometryReader { geometry in
            let showsUtilityPanel = geometry.size.width >= 1_360
            let todayWidth = min(455, max(345, geometry.size.width * 0.22))
            let utilityWidth = min(455, max(320, geometry.size.width * 0.22))

            HStack(spacing: 12) {
                TodayView(showsTaskEditor: $showsTaskEditor, showsUtilityPanel: false)
                    .frame(width: todayWidth)
                    .workspacePanel()

                PlanCalendarView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .workspacePanel()

                if showsUtilityPanel {
                    TodayUtilityPanel()
                        .frame(width: utilityWidth)
                        .workspacePanel()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color.yanxuCanvas)
    }
}

private struct WorkspacePanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.yanxuCard)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.yanxuBorder, lineWidth: 1)
            }
    }
}

private extension View {
    func workspacePanel() -> some View {
        modifier(WorkspacePanelModifier())
    }
}
