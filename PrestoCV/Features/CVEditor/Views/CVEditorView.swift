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
        .task {
            // Load CV data when the view appears
            await viewModel.loadCV()
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
                viewModel.clearError()
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
            Section("CV Details") {
                TextField("CV Name", text: $viewModel.cv.name)
            }
            
            Section("Personal Information") {
                TextField("Full Name", text: $viewModel.cv.personalInfo.name)
                TextField("Professional Title", text: $viewModel.cv.personalInfo.title)
                TextField("Location", text: $viewModel.cv.personalInfo.location)
                TextField("Email", text: $viewModel.cv.personalInfo.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                TextField("Phone", text: $viewModel.cv.personalInfo.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Portfolio URL", text: $viewModel.cv.personalInfo.portfolio)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                
                TextEditor(text: $viewModel.cv.personalInfo.profile)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.tertiary, lineWidth: 1)
                    )
                    .padding(.vertical, DesignTokens.Spacing.xxs)
            }
            
            Section("Skills") {
                ForEach(viewModel.cv.skills.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        TextField("Skill", text: $viewModel.cv.skills[index].name)
                        SkillLevelView(
                            level: $viewModel.cv.skills[index].level,
                            maxLevel: 5
                        )
                        .padding(.bottom, DesignTokens.Spacing.xs)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.skills.remove(atOffsets: indices)
                }
                
                Button("Add Skill") {
                    viewModel.addSkill()
                }
            }
            
            Section("Experience") {
                ForEach(viewModel.cv.relevant_experience.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        TextField("Job Title", text: $viewModel.cv.relevant_experience[index].title)
                        TextField("Company", text: $viewModel.cv.relevant_experience[index].company)
                        TextField("Location", text: $viewModel.cv.relevant_experience[index].location)
                        TextField("Period", text: $viewModel.cv.relevant_experience[index].period)
                        TextEditor(text: $viewModel.cv.relevant_experience[index].description)
                            .frame(height: DesignTokens.Spacing.xxl)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.relevant_experience.remove(atOffsets: indices)
                }
                
                Button("Add Experience") {
                    viewModel.addExperience()
                }
            }
            
            Section("Education") {
                ForEach(viewModel.cv.education.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        TextField("Degree", text: $viewModel.cv.education[index].degree)
                        TextField("School", text: $viewModel.cv.education[index].school)
                        TextField("Period", text: $viewModel.cv.education[index].period)
                        TextEditor(text: $viewModel.cv.education[index].description)
                            .frame(height: DesignTokens.Spacing.xxl)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.education.remove(atOffsets: indices)
                }
                
                Button("Add Education") {
                    viewModel.addEducation()
                }
            }
            
            Section("Languages") {
                ForEach(viewModel.cv.languages.indices, id: \.self) { index in
                    HStack {
                        TextField("Language", text: $viewModel.cv.languages[index].name)
                        TextField("Level", text: $viewModel.cv.languages[index].level)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.languages.remove(atOffsets: indices)
                }
                
                Button("Add Language") {
                    viewModel.addLanguage()
                }
            }
            
            Section("Certifications") {
                ForEach(viewModel.cv.certifications.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        TextField("Name", text: $viewModel.cv.certifications[index].name)
                        TextField("Issuer", text: $viewModel.cv.certifications[index].issuer)
                        TextField("Year", text: Binding(
                            get: { String(viewModel.cv.certifications[index].year) },
                            set: { newValue in
                                viewModel.cv.certifications[index].year = Int(newValue) ?? 0
                            }
                        ))
                        .keyboardType(.numberPad)
                        TextField("URL", text: $viewModel.cv.certifications[index].url)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                        TextEditor(text: $viewModel.cv.certifications[index].description)
                            .frame(height: DesignTokens.Spacing.xl)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.certifications.remove(atOffsets: indices)
                }
                
                Button("Add Certification") {
                    viewModel.addCertification()
                }
            }
            
            Section("Social Links") {
                ForEach(viewModel.cv.social.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        TextField("Platform", text: $viewModel.cv.social[index].platform)
                        TextField("URL", text: $viewModel.cv.social[index].url)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                    }
                }
                .onDelete { indices in
                    viewModel.cv.social.remove(atOffsets: indices)
                }
                
                Button("Add Social Link") {
                    viewModel.addSocial()
                }
            }
            
            Section("Interests") {
                ForEach(viewModel.cv.interests.indices, id: \.self) { index in
                    TextField("Interest", text: Binding(
                        get: { viewModel.cv.interests[index] },
                        set: { newValue in
                            viewModel.cv.interests[index] = newValue
                        }
                    ))
                }
                .onDelete { indices in
                    viewModel.cv.interests.remove(atOffsets: indices)
                }
                
                Button("Add Interest") {
                    viewModel.addInterest()
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