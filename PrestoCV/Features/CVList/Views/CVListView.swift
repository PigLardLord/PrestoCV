import SwiftUI
import PrestoCVCore

struct CVListView: View {
    @ObservedObject var viewModel: CVListViewModel
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.cvs.isEmpty {
                    emptyStateView
                } else {
                    cvListView
                }
            }
            .navigationTitle("My CVs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        router.navigate(to: .templateSelection)
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.loadCVs()
            }
            .refreshable {
                await viewModel.loadCVs()
            }
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        LoadingView.fullscreen(message: "Loading your CVs...")
    }
    
    private var emptyStateView: some View {
        EmptyStateView.noCVs {
            router.navigate(to: .templateSelection)
        }
    }
    
    private var cvListView: some View {
        List {
            ForEach(viewModel.cvs) { cv in
                CVRowView(cv: cv) {
                    router.navigate(to: .cvEditor(cvId: cv.id.uuidString))
                }
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await viewModel.deleteCV(withId: viewModel.cvs[index].id)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - CV Row View

private struct CVRowView: View {
    let cv: CVModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(cv.name.isEmpty ? "Untitled CV" : cv.name)
                        .typography(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                        .lineLimit(1)
                    
                    if !cv.personalInfo.title.isEmpty {
                        Text(cv.personalInfo.title)
                            .typography(.subheadline)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .lineLimit(1)
                    }
                    
                    if !cv.personalInfo.location.isEmpty {
                        Text(cv.personalInfo.location)
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(DesignTokens.IconSize.small.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }
            .padding(.vertical, DesignTokens.Spacing.xxs)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("CV: \(cv.name.isEmpty ? "Untitled" : cv.name)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

struct CVListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVListView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> CVListViewModel {
        let container = DependencyContainer()
        do {
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            return CVListViewModel(cvManagementUseCase: cvManagementUseCase)
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}