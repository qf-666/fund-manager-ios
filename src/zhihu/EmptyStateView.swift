import SwiftUI

struct EmptyStateView<Description: View>: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let description: Description

    init(_ title: LocalizedStringKey, systemImage: String) where Description == EmptyView {
        self.title = title
        self.systemImage = systemImage
        self.description = EmptyView()
    }

    init(_ title: LocalizedStringKey, systemImage: String, description: Description) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            description
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(24)
    }
}
