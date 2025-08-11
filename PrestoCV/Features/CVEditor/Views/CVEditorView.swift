import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: CVEditorViewModel
    @State private var showingSaveConfirmation = false
    
    init(viewModel: CVEditorViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else {
                editorView
            }
        }
        .navigationTitle(viewModel.cv.name.isEmpty ? "New CV" : viewModel.cv.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    router.navigateBack()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        if await viewModel.saveCV() {
                            showingSaveConfirmation = true
                        }
                    }
                }
                .disabled(viewModel.cv.name.isEmpty)
            }
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
                viewModel.errorMessage = ""
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("CV Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                router.navigateBack()
            }
        } message: {
            Text("Your CV has been saved successfully.")
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        LoadingView.fullscreen(message: "Loading...")
    }
    
    private var errorView: some View {
        ErrorView.generic(
            message: viewModel.errorMessage,
            onRetry: {
                Task {
                    await viewModel.loadCV()
                }
            }
        )
    }
    
    private var editorView: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("CV Name", text: $viewModel.cv.name)
                TextField("Professional Title", text: $viewModel.cv.title)
                TextField("Location", text: $viewModel.cv.location)
                TextField("Email", text: $viewModel.cv.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                TextField("Phone", text: $viewModel.cv.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Portfolio URL", text: $viewModel.cv.portfolio)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                
                TextEditor(text: $viewModel.cv.profile)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("Skills")) {
                ForEach(viewModel.cv.skills.indices, id: \.self) { index in
                    TextField("Skill", text: $viewModel.cv.skills[index].name)
                }
                .onDelete { indices in
                    viewModel.cv.skills.remove(atOffsets: indices)
                }
                
                Button("Add Skill") {
                    viewModel.addSkill()
                }
            }
            
            Section(header: Text("Experience")) {
                ForEach(viewModel.cv.relevant_experience.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Job Title", text: $viewModel.cv.relevant_experience[index].title)
                        TextField("Company", text: $viewModel.cv.relevant_experience[index].company)
                        TextField("Location", text: $viewModel.cv.relevant_experience[index].location)
                        TextField("Description", text: $viewModel.cv.relevant_experience[index].description)
                            .frame(height: 60)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.relevant_experience.remove(atOffsets: indices)
                }
                
                Button("Add Experience") {
                    viewModel.addExperience()
                }
            }
        }
    }
}

// MARK: - Previews

struct CVEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CVEditorView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> CVEditorViewModel {
        let container = DependencyContainer()
        do {
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            return CVEditorViewModel(
                cvId: nil,
                cvManagementUseCase: cvManagementUseCase
            )
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}