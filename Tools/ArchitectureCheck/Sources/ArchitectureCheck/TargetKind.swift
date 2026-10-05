/// What a target is. A misspelt kind in `rules.json` would leave a production target without its detectors while the
/// modules check still treated it as production, so decoding refuses a word that is not one of these.
enum TargetKind: String, ClosedSet {
    case production, test, tool, manifest, legacy, excluded

    static let subject = "target kind"
}
