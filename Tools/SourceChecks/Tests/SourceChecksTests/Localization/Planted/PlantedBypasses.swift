// A planted source for the self-test of the string checks (StringChecksSelfTests): English words that reach a view by
// other ways than a literal handed straight to it. It is excluded from the build and has no import, because the
// architecture check reads it as source.

struct PlantedBypasses {
    // Text("Commented words") is not shipped
    /// "Documented words" are not shipped either
    let count = 1 // "Trailing words"

    var body: Void {
        Text(isReady ? "Ready to send" : "Try once more")
        let heading = "Name your resume"
        Text(heading)
        let intro = """
            Tell us about your last job
            """
        Text(intro)
        Text("Review your draft".uppercased())
        Text(#"Raw words here"#)

        Text(verbatim: "Plain words here")
        view.accessibilityIdentifier("profile.save.button")
        Image(systemName: "doc.text")
        Label("plant.complete", systemImage: "doc.richtext")
        Image(named: "hero-banner")
        Text("plant.complete".uppercased())
        Text("plant.complete".localized.uppercased())
        Text(String(localized: "plant.complete"))
        Text(LocalizedStringKey("plant.complete"))
    }
}
