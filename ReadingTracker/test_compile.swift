import SwiftUI
struct TestView: View {
    var body: some View {
        Text("Test")
            .toolbar(removing: .sidebarToggle)
    }
}
