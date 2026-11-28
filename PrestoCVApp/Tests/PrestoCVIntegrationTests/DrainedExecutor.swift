import Foundation
import Synchronization

/// A task executor that runs nothing by itself: the jobs of a task that prefers it wait until the test drains them, so
/// a task resumed meanwhile stays where it was until then. Once drained, such a task has gone as far as it can: it waits
/// on something else, or it ended, on every run. Its code stays on the executor only where no actor takes it elsewhere.
final class DrainedExecutor: TaskExecutor {
    private struct State {
        var jobs: [UnownedJob] = []
        var released = false
    }

    private let state = Mutex(State())

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let runs = state.withLock { state in
            if !state.released { state.jobs.append(job) }
            return state.released
        }
        if runs { start([job]) }
    }

    /// Runs the jobs that wait, and those they enqueue, on a thread of its own, and returns once none is left: the
    /// tasks that prefer the executor then wait on something else, or ended.
    func drain() async {
        await withCheckedContinuation { (drained: CheckedContinuation<Void, Never>) in
            Thread {
                while let job = self.state.withLock({ $0.jobs.isEmpty ? nil : $0.jobs.removeFirst() }) {
                    job.runSynchronously(on: self.asUnownedTaskExecutor())
                }
                drained.resume()
            }.start()
        }
    }

    /// Runs the jobs that wait, then every job at once, as an executor of its own would: a test that has seen where the
    /// tasks wait lets them go on without draining again.
    func letGo() {
        let waiting = state.withLock { state in
            defer { state.jobs = [] }
            state.released = true
            return state.jobs
        }
        start(waiting)
    }

    private func start(_ jobs: [UnownedJob]) {
        guard !jobs.isEmpty else { return }
        Thread {
            for job in jobs { job.runSynchronously(on: self.asUnownedTaskExecutor()) }
        }.start()
    }
}
