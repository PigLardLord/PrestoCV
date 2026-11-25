/// Removes what the released app left under Application Support and holds nothing the person wrote: its design files, their
/// cache and its export settings. The launch owns this port (R3); its adapter is `LegacyLeftoversAdapter`, in
/// `PrestoCVLegacyLeftovers`. Contents, layer and allowed imports: docs/architecture/modules.md.
///
/// The work is file work, so the requirement is `async` and the adapter runs it off the main actor (R19).
public protocol LegacyLeftoversCleaning: Sendable {
    /// Removes the leftovers that are there; one already gone is fine. A removal that fails is logged, never thrown, and
    /// the others still go: the next launch tries again.
    func clean() async
}
