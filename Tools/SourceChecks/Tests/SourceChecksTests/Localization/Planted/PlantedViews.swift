// A planted source for the self-test of the string checks (StringChecksSelfTests). It is excluded from the build.
// (It has no import: the architecture check reads it as source.)

struct PlantedViews {
    var body: Void {
        VStack {
            Text("plant.complete")
            Text("plant.no_german")
            Text("plant.not_translated")
            Text("plant.copied")
            Text("plant.placeholders")
            Text("plant.promise")
            Text("plant.title_case")
            Text("plant.empty_translation")
            Text("plant.empty_english")
            Text("plant.unmarked_english")
            Text("plant.review_english")
            Text("plant.absent".localized)
        }
    }
}
