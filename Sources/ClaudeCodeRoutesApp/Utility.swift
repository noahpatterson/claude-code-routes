import Foundation

public func checkPathIsExecutable(atPath: URL) -> Bool {
  return FileManager.default.isExecutableFile(atPath: atPath.path)
}
