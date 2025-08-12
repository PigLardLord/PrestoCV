import SwiftUI
import PrestoCVCore

struct CVEditorView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: CVEditorViewModel
    @State private var showingSaveConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var saveSuccessTimer: Timer?
    
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
            // Leading: Cancel button with confirmation if unsaved changes
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if viewModel.hasUnsavedChanges {
                        showingCancelConfirmation = true
                    } else {
                        router.navigateBack()
                    }
                }
                .foregroundColor(DesignTokens.Colors.accent)
            }
            
            // Principal: Progress indicator (subtle)
            ToolbarItem(placement: .principal) {
                VStack(spacing: DesignTokens.Spacing.xxxs) {
                    Text(viewModel.cv.name.isEmpty ? "New CV" : viewModel.cv.name)
                        .font(DesignTokens.Typography.headline.font)
                        .fontWeight(DesignTokens.Typography.headline.fontWeight)
                        .lineLimit(1)
                    
                    // Progress bar - only show if there's meaningful content
                    if viewModel.hasMeaningfulContent {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                    .fill(DesignTokens.Colors.backgroundTertiary)
                                    .frame(height: 2)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                    .fill(DesignTokens.Colors.accent)
                                    .frame(width: geometry.size.width * viewModel.completionPercentage, height: 2)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.completionPercentage)
                            }
                        }
                        .frame(height: 2)
                    }
                }
            }
            
            // Trailing: Save button with smart state and visual indicator
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    // Unsaved changes indicator
                    if viewModel.hasUnsavedChanges {
                        Circle()
                            .fill(DesignTokens.Colors.warning)
                            .frame(width: 6, height: 6)
                    }
                    
                    Button("Save") {
                        Task {
                            if await viewModel.saveCV() {
                                showingSaveConfirmation = true
                                
                                // Auto-dismiss after 2 seconds
                                saveSuccessTimer?.invalidate()
                                saveSuccessTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                    showingSaveConfirmation = false
                                    router.navigateBack()
                                }
                            }
                        }
                    }
                    .disabled(!viewModel.hasMeaningfulContent || viewModel.isLoading)
                    .foregroundColor(viewModel.hasMeaningfulContent && !viewModel.isLoading ? 
                                   DesignTokens.Colors.accent : DesignTokens.Colors.disabledButtonForeground)
                    .fontWeight(.semibold)
                }
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
        .alert("Discard Changes?", isPresented: $showingCancelConfirmation) {
            Button("Discard", role: .destructive) {
                router.navigateBack()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes that will be lost if you continue.")
        }
        .alert("CV Saved Successfully", isPresented: $showingSaveConfirmation) {
            Button("Continue Editing") {
                saveSuccessTimer?.invalidate()
                showingSaveConfirmation = false
            }
            Button("Done") {
                saveSuccessTimer?.invalidate()
                router.navigateBack()
            }
        } message: {
            Text("Your changes have been saved.")
        }
        .onDisappear {
            // Clean up timer when view disappears
            saveSuccessTimer?.invalidate()
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
        TabView {
            // MARK: - Basics Tab
            basicsTab
                .tabItem {
                    Label("Basics", systemImage: "person.circle")
                }
            
            // MARK: - Experience Tab
            experienceTab
                .tabItem {
                    Label("Experience", systemImage: "briefcase")
                }
            
            // MARK: - Details Tab
            detailsTab
                .tabItem {
                    Label("Details", systemImage: "list.bullet.circle")
                }
        }
        .background(DesignTokens.Colors.background)
    }
    
    // MARK: - Basics Tab Content
    
    private var basicsTab: some View {
        Form {
            // CV Name Section - Most Important
            Section {
                TextField("CV Name", text: $viewModel.cv.name)
                    .font(DesignTokens.Typography.headline.font)
                    .fontWeight(DesignTokens.Typography.headline.fontWeight)
            } header: {
                Text("CV Details")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            .listRowBackground(DesignTokens.Colors.backgroundSecondary)
            
            // Personal Information - High Priority
            Section {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    LabeledTextField(label: "Full Name", text: $viewModel.cv.personalInfo.name)
                    
                    LabeledTextField(label: "Professional Title", text: $viewModel.cv.personalInfo.title)
                    
                    LabeledTextField(label: "Location", text: $viewModel.cv.personalInfo.location)
                    
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        LabeledTextField.email(
                            text: $viewModel.cv.personalInfo.email,
                            isRequired: true
                        )
                        
                        LabeledTextField.phone(
                            text: $viewModel.cv.personalInfo.phone
                        )
                    }
                    
                    LabeledTextField.url(
                        label: "Portfolio URL",
                        text: $viewModel.cv.personalInfo.portfolio
                    )
                }
            } header: {
                Text("Personal Information")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            
            // Professional Summary - High Priority
            Section {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Professional Summary")
                        .font(DesignTokens.Typography.subheadline.font)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    Text("Describe your professional background, key skills, and career objectives")
                        .font(DesignTokens.Typography.caption1.font)
                        .foregroundColor(DesignTokens.Colors.secondary)
                        .padding(.bottom, DesignTokens.Spacing.xs)
                    
                    TextEditor(text: $viewModel.cv.personalInfo.profile)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(DesignTokens.Colors.backgroundTertiary)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                }
            } header: {
                Text("Summary")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Experience Tab Content
    
    private var experienceTab: some View {
        Form {
            // Work Experience - Most Important
            Section {
                if viewModel.cv.relevant_experience.isEmpty {
                    emptyStateView(
                        icon: "briefcase",
                        title: "No Experience Added",
                        subtitle: "Add your work experience to showcase your professional background"
                    )
                } else {
                    ForEach(viewModel.cv.relevant_experience.indices, id: \.self) { index in
                        experienceRow(at: index)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.relevant_experience.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Experience", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addExperience()
                    }
                }
            } header: {
                Text("Work Experience")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            
            // Skills Section
            Section {
                if viewModel.cv.skills.isEmpty {
                    emptyStateView(
                        icon: "star.circle",
                        title: "No Skills Added",
                        subtitle: "Add your technical and professional skills"
                    )
                } else {
                    ForEach(viewModel.cv.skills.indices, id: \.self) { index in
                        skillRow(at: index)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.skills.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Skill", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addSkill()
                    }
                }
            } header: {
                Text("Skills")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            
            // Education Section
            Section {
                if viewModel.cv.education.isEmpty {
                    emptyStateView(
                        icon: "graduationcap.circle",
                        title: "No Education Added",
                        subtitle: "Add your educational background and qualifications"
                    )
                } else {
                    ForEach(viewModel.cv.education.indices, id: \.self) { index in
                        educationRow(at: index)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.education.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Education", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addEducation()
                    }
                }
            } header: {
                Text("Education")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Details Tab Content
    
    private var detailsTab: some View {
        Form {
            // Languages Section
            Section {
                if viewModel.cv.languages.isEmpty {
                    emptyStateView(
                        icon: "globe",
                        title: "No Languages Added",
                        subtitle: "Add languages you speak and your proficiency level"
                    )
                } else {
                    ForEach(viewModel.cv.languages.indices, id: \.self) { index in
                        languageRow(at: index)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.languages.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Language", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addLanguage()
                    }
                }
            } header: {
                Text("Languages")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            
            // Certifications Section
            Section {
                if viewModel.cv.certifications.isEmpty {
                    emptyStateView(
                        icon: "rosette",
                        title: "No Certifications Added",
                        subtitle: "Add professional certifications and achievements"
                    )
                } else {
                    ForEach(viewModel.cv.certifications.indices, id: \.self) { index in
                        certificationRow(at: index)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.certifications.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Certification", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addCertification()
                    }
                }
            } header: {
                Text("Certifications")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            
            // Social Links Section
            Section {
                if viewModel.cv.social.isEmpty {
                    emptyStateView(
                        icon: "link.circle",
                        title: "No Social Links Added",
                        subtitle: "Add professional social media profiles and websites"
                    )
                } else {
                    ForEach(viewModel.cv.social.indices, id: \.self) { index in
                        socialLinkRow(at: index)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.social.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Social Link", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addSocial()
                    }
                }
            } header: {
                Text("Social Links")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
            
            // Interests Section
            Section {
                if viewModel.cv.interests.isEmpty {
                    emptyStateView(
                        icon: "heart.circle",
                        title: "No Interests Added",
                        subtitle: "Add personal interests and hobbies"
                    )
                } else {
                    ForEach(viewModel.cv.interests.indices, id: \.self) { index in
                        interestRow(at: index)
                    }
                    .onDelete { indices in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.cv.interests.remove(atOffsets: indices)
                        }
                    }
                }
                
                addButton(title: "Add Interest", icon: "plus.circle.fill") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.addInterest()
                    }
                }
            } header: {
                Text("Interests")
                    .font(DesignTokens.Typography.title3.font)
                    .fontWeight(DesignTokens.Typography.title3.fontWeight)
                    .foregroundColor(DesignTokens.Typography.title3.color)
                    .textCase(nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Row Components
    
    private func experienceRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("Job Title", text: $viewModel.cv.relevant_experience[index].title)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                deleteButton {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.removeExperience(at: index)
                    }
                }
            }
            
            TextField("Company", text: $viewModel.cv.relevant_experience[index].company)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            HStack {
                TextField("Location", text: $viewModel.cv.relevant_experience[index].location)
                Spacer()
                TextField("Period", text: $viewModel.cv.relevant_experience[index].period)
                    .multilineTextAlignment(.trailing)
            }
            .font(DesignTokens.Typography.callout.font)
            .foregroundColor(DesignTokens.Colors.tertiary)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Description")
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $viewModel.cv.relevant_experience[index].description)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
    
    private func skillRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                TextField("Skill", text: $viewModel.cv.skills[index].name)
                    .font(DesignTokens.Typography.subheadline.font)
                Spacer()
                deleteButton {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.removeSkill(at: index)
                    }
                }
            }
            
            SkillLevelView(
                level: $viewModel.cv.skills[index].level,
                maxLevel: 5
            )
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    private func educationRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("Degree", text: $viewModel.cv.education[index].degree)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                deleteButton {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.removeEducation(at: index)
                    }
                }
            }
            
            TextField("School", text: $viewModel.cv.education[index].school)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            TextField("Period", text: $viewModel.cv.education[index].period)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Description")
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $viewModel.cv.education[index].description)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
    
    private func languageRow(at index: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            TextField("Language", text: $viewModel.cv.languages[index].name)
                .font(DesignTokens.Typography.body.font)
            
            TextField("Level", text: $viewModel.cv.languages[index].level)
                .multilineTextAlignment(.trailing)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.secondary)
                .frame(maxWidth: 100)
            
            deleteButton {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.removeLanguage(at: index)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    private func certificationRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                TextField("Certification Name", text: $viewModel.cv.certifications[index].name)
                    .font(DesignTokens.Typography.subheadline.font)
                    .fontWeight(.semibold)
                Spacer()
                deleteButton {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.removeCertification(at: index)
                    }
                }
            }
            
            TextField("Issuer", text: $viewModel.cv.certifications[index].issuer)
                .font(DesignTokens.Typography.body.font)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            HStack {
                TextField("Year", text: Binding(
                    get: { String(viewModel.cv.certifications[index].year) },
                    set: { newValue in
                        viewModel.cv.certifications[index].year = Int(newValue) ?? 0
                    }
                ))
                .keyboardType(.numberPad)
                .font(DesignTokens.Typography.callout.font)
                .frame(maxWidth: 80)
                
                Spacer()
                
                TextField("URL", text: $viewModel.cv.certifications[index].url)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .font(DesignTokens.Typography.callout.font)
                    .foregroundColor(DesignTokens.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Description")
                    .font(DesignTokens.Typography.footnote.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
                
                TextEditor(text: $viewModel.cv.certifications[index].description)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.backgroundTertiary)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
            }
        }
        .cardStyle()
    }
    
    private func socialLinkRow(at index: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            TextField("Platform", text: $viewModel.cv.social[index].platform)
                .font(DesignTokens.Typography.body.font)
                .frame(maxWidth: 100)
            
            TextField("URL", text: $viewModel.cv.social[index].url)
                .textContentType(.URL)
                .keyboardType(.URL)
                .font(DesignTokens.Typography.callout.font)
                .foregroundColor(DesignTokens.Colors.accent)
            
            deleteButton {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.removeSocial(at: index)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    private func interestRow(at index: Int) -> some View {
        HStack {
            TextField("Interest", text: Binding(
                get: { viewModel.cv.interests[index] },
                set: { newValue in
                    viewModel.cv.interests[index] = newValue
                }
            ))
            .font(DesignTokens.Typography.body.font)
            
            Spacer()
            
            deleteButton {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.removeInterest(at: index)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    // MARK: - Helper Views
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignTokens.IconSize.large.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
            
            Text(title)
                .font(DesignTokens.Typography.subheadline.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.secondary)
            
            Text(subtitle)
                .font(DesignTokens.Typography.caption1.font)
                .foregroundColor(DesignTokens.Colors.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
    
    private func addButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DesignTokens.Typography.callout.font)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Colors.accent)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
    
    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(DesignTokens.IconSize.small.font)
                .foregroundColor(DesignTokens.Colors.error)
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
