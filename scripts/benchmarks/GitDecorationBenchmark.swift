import Foundation

/// Microbenchmark of the production row-decoration model, excluding Git I/O
/// and AppKit rendering. Run with scripts/verify-git-decoration.sh.
@main
enum GitDecorationBenchmark {
  static func main() {
    for prefixCount in [0, 1, 10, 100, 1000] {
      let snapshot = GitStatusSnapshot(
        ignoredPrefixes: Set((0..<prefixCount).map { "ignored/dir\($0)" })
      )
      let paths = (0..<1000).map {
        $0.isMultiple(of: 2)
          ? "sources/module/file\($0).swift"
          : "ignored/dir\($0 % max(prefixCount, 1))/file.swift"
      }
      var samples: [Double] = []
      var checksum = 0
      for sample in 0..<6 {
        let start = ContinuousClock.now
        for _ in 0..<10 {
          for path in paths {
            if snapshot.decoration(for: path, isDirectory: false, isExpanded: false) == .ignored {
              checksum += 1
            }
          }
        }
        let duration = start.duration(to: .now).components
        if sample > 0 {
          samples.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
        }
      }
      precondition(checksum == (prefixCount == 0 ? 0 : 30_000))
      let median = samples.sorted()[samples.count / 2]
      let line = "prefixes=\(prefixCount) lookups=10000 median_ms=\(median) checksum=\(checksum)\n"
      FileHandle.standardOutput.write(Data(line.utf8))
    }
  }
}
