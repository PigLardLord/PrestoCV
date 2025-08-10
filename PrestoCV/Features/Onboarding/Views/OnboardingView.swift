import SwiftUI
import PrestoCVCore

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Welcome Section
            welcomeSection
            
            // Action Section
            actionSection
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Welcome to PrestoCV")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Create professional CVs easily and manage all your career documents in one place.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            // Create First CV Button
            Button(action: {
                Task {
                    await viewModel.createFirstCV()
                    // Navigation will be handled automatically via state change
                }
            }) {
                HStack {
                    if viewModel.isCreatingCV {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(viewModel.isCreatingCV ? "Creating..." : "Create Your First CV")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(viewModel.isCreatingCV)
            
            // Skip for now - placeholder for future feature
            Button("Skip for now") {
                router.replace(with: .cvList)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Error Handling

extension OnboardingView {
    private var errorAlert: some View {
        Text("Error Alert - TODO")
    }
}

// MARK: - Previews

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OnboardingView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> OnboardingViewModel {
        // This is a simplified mock for preview purposes
        // In a real implementation, we'd want proper mock dependencies
        let container = DependencyContainer()
        do {
            let onboardingUseCase = try container.makeOnboardingUseCase()
            let templateRepository = try container.makeTemplateRepository()
            return OnboardingViewModel(
                onboardingUseCase: onboardingUseCase,
                templateRepository: templateRepository
            )
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}