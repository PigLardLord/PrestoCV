/// Lets every task that can run, run: the tasks waiting on the main actor, and the work they hand to `repository`, which
/// is answered in the order it came. A test uses it to say "nothing more happens now" before it checks that nothing did.
func settle(_ repository: InMemoryCVRepository, rounds: Int = 20) async {
    for _ in 0..<rounds {
        await Task.yield()
        _ = await repository.saveCount
    }
}
