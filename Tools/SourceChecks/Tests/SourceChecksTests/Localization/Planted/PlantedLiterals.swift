// A planted source for the self-test of the string checks (StringChecksSelfTests): literals handed to views. It is
// excluded from the build and has no import, because the architecture check reads it as source.

struct PlantedLiterals {
    var body: Void {
        Text("plant.complete")
        Button("plant.complete") {}
        Text("plant.titel")
        Label("Save your CV", systemImage: "doc")
        Text("\(count) pages")
        Text("\(first) / \(second)")
        Text("42")
        Text("PDF")
        Text(verbatim: "PrestoCV")
        Text(title)
        view.navigationTitle("plant.complete")
        view.navigationTitle("plant.heading")
        view.accessibilityLabel("plant.complete")
        view.accessibilityHint("Double tap to save")
        ScreenTitle("plant.screen_title")
        ErrorBox(title: "plant.box_title", detail: "plant.complete")
        Text("plant.unused".localized)
    }
}
