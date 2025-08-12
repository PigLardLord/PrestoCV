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
                // These benefit from labels since they're grouped together
                LabeledTextField(label: "Full Name", text: $viewModel.cv.personalInfo.name)
                LabeledTextField(label: "Professional Title", text: $viewModel.cv.personalInfo.title)
                LabeledTextField(label: "Location", text: $viewModel.cv.personalInfo.location)
                LabeledTextField(label: "Email", text: $viewModel.cv.personalInfo.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                LabeledTextField(label: "Phone", text: $viewModel.cv.personalInfo.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                LabeledTextField(label: "Portfolio URL", text: $viewModel.cv.personalInfo.portfolio)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                
                // Description fields benefit from labels
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Professional Summary")
                        .font(DesignTokens.Typography.footnote.font)
                        .foregroundColor(DesignTokens.Colors.secondary)
                    
                    TextEditor(text: $viewModel.cv.personalInfo.profile)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                .stroke(DesignTokens.Colors.tertiary, lineWidth: 1)
                        )
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                }
            }
            
            Section("Skills") {
                if viewModel.cv.skills.isEmpty {
                    Text("No skills added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.skills.indices, id: \.self) { index in
                        HStack {
                            TextField("Skill", text: $viewModel.cv.skills[index].name)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    viewModel.removeSkill(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(DesignTokens.Colors.error)
                            }
                        }
                        SkillLevelView(
                            level: $viewModel.cv.skills[index].level,
                            maxLevel: 5
                        )
                        .padding(.bottom, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.skills.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addSkill()
                    }
                }) {
                    Label("Add Skill", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            
            Section("Experience") {
                if viewModel.cv.relevant_experience.isEmpty {
                    Text("No experience added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.relevant_experience.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            HStack {
                                TextField("Job Title", text: $viewModel.cv.relevant_experience[index].title)
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        viewModel.removeExperience(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(DesignTokens.Colors.error)
                                }
                            }
                            
                            TextField("Company", text: $viewModel.cv.relevant_experience[index].company)
                            
                            HStack {
                                TextField("Location", text: $viewModel.cv.relevant_experience[index].location)
                                TextField("Period", text: $viewModel.cv.relevant_experience[index].period)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            // Description fields benefit from labels
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                Text("Description")
                                    .font(DesignTokens.Typography.footnote.font)
                                    .foregroundColor(DesignTokens.Colors.secondary)
                                
                                TextEditor(text: $viewModel.cv.relevant_experience[index].description)
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                            .stroke(DesignTokens.Colors.tertiary, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.relevant_experience.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addExperience()
                    }
                }) {
                    Label("Add Experience", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            
            Section("Education") {
                if viewModel.cv.education.isEmpty {
                    Text("No education added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.education.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            HStack {
                                TextField("Degree", text: $viewModel.cv.education[index].degree)
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        viewModel.removeEducation(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(DesignTokens.Colors.error)
                                }
                            }
                            
                            TextField("School", text: $viewModel.cv.education[index].school)
                            
                            HStack {
                                TextField("Period", text: $viewModel.cv.education[index].period)
                                Spacer()
                            }
                            
                            // Description fields benefit from labels
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                Text("Description")
                                    .font(DesignTokens.Typography.footnote.font)
                                    .foregroundColor(DesignTokens.Colors.secondary)
                                
                                TextEditor(text: $viewModel.cv.education[index].description)
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                            .stroke(DesignTokens.Colors.tertiary, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.education.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addEducation()
                    }
                }) {
                    Label("Add Education", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            
            Section("Languages") {
                if viewModel.cv.languages.isEmpty {
                    Text("No languages added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.languages.indices, id: \.self) { index in
                        HStack {
                            TextField("Language", text: $viewModel.cv.languages[index].name)
                            TextField("Level", text: $viewModel.cv.languages[index].level)
                                .multilineTextAlignment(.trailing)
                            
                            Button(action: {
                                withAnimation {
                                    viewModel.removeLanguage(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(DesignTokens.Colors.error)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.languages.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addLanguage()
                    }
                }) {
                    Label("Add Language", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            
            Section("Certifications") {
                if viewModel.cv.certifications.isEmpty {
                    Text("No certifications added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.certifications.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            HStack {
                                TextField("Certification Name", text: $viewModel.cv.certifications[index].name)
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        viewModel.removeCertification(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(DesignTokens.Colors.error)
                                }
                            }
                            
                            TextField("Issuer", text: $viewModel.cv.certifications[index].issuer)
                            
                            HStack {
                                TextField("Year", text: Binding(
                                    get: { String(viewModel.cv.certifications[index].year) },
                                    set: { newValue in
                                        viewModel.cv.certifications[index].year = Int(newValue) ?? 0
                                    }
                                ))
                                .keyboardType(.numberPad)
                                .frame(maxWidth: 100)
                                
                                Spacer()
                                
                                TextField("URL", text: $viewModel.cv.certifications[index].url)
                                    .textContentType(.URL)
                                    .keyboardType(.URL)
                            }
                            
                            // Description fields benefit from labels
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                Text("Description")
                                    .font(DesignTokens.Typography.footnote.font)
                                    .foregroundColor(DesignTokens.Colors.secondary)
                                
                                TextEditor(text: $viewModel.cv.certifications[index].description)
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                            .stroke(DesignTokens.Colors.tertiary, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.certifications.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addCertification()
                    }
                }) {
                    Label("Add Certification", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            
            Section("Social Links") {
                if viewModel.cv.social.isEmpty {
                    Text("No social links added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.social.indices, id: \.self) { index in
                        HStack {
                            TextField("Platform", text: $viewModel.cv.social[index].platform)
                            TextField("URL", text: $viewModel.cv.social[index].url)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                            
                            Button(action: {
                                withAnimation {
                                    viewModel.removeSocial(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(DesignTokens.Colors.error)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.social.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addSocial()
                    }
                }) {
                    Label("Add Social Link", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            
            Section("Interests") {
                if viewModel.cv.interests.isEmpty {
                    Text("No interests added")
                        .foregroundColor(DesignTokens.Colors.tertiary)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                } else {
                    ForEach(viewModel.cv.interests.indices, id: \.self) { index in
                        HStack {
                            TextField("Interest", text: Binding(
                                get: { viewModel.cv.interests[index] },
                                set: { newValue in
                                    viewModel.cv.interests[index] = newValue
                                }
                            ))
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    viewModel.removeInterest(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(DesignTokens.Colors.error)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation {
                            viewModel.cv.interests.remove(atOffsets: indices)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.addInterest()
                    }
                }) {
                    Label("Add Interest", systemImage: "plus")
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
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