import Foundation

/// Resolves paths supplied by a model and guarantees they stay inside the
/// project folder.
///
/// This is a security boundary (docs/security/permissions.md). Symlinks are
/// resolved *before* the containment check, including for paths that do not
/// exist yet: the deepest existing ancestor is resolved and the missing
/// components are re-appended, so `link-to-etc/new-file` cannot escape even
/// though `new-file` does not exist.
enum ProjectBoundary {
    /// Returns the absolute, symlink-resolved URL for `path`.
    ///
    /// `path` may be relative to the project root or absolute. An empty path
    /// means the root itself. `~` is refused rather than expanded.
    ///
    /// - Throws: `ToolError.outsideProjectBoundary` when the resolved location
    ///   is not the root or one of its descendants.
    static func resolve(_ path: String, in root: URL) throws(ToolError) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.isEmpty ? "." : trimmed
        guard !raw.hasPrefix("~") else { throw .outsideProjectBoundary(path: raw) }

        let resolvedRoot = resolveExisting(root.standardizedFileURL)
        let candidate = raw.hasPrefix("/") ? URL(fileURLWithPath: raw) : resolvedRoot.appending(path: raw)
        let resolved = resolveExisting(candidate.standardizedFileURL)
        guard contains(resolved, root: resolvedRoot) else { throw .outsideProjectBoundary(path: raw) }
        return resolved
    }

    /// Path of `url` relative to `root` (“.” for the root itself), for display
    /// and for tool output.
    static func relativePath(of url: URL, in root: URL) -> String {
        let rootPath = resolveExisting(root.standardizedFileURL).path
        let path = resolveExisting(url.standardizedFileURL).path
        guard path.hasPrefix(rootPath) else { return path }
        let relative = path.dropFirst(rootPath.count).drop { $0 == "/" }
        return relative.isEmpty ? "." : String(relative)
    }

    static func contains(_ url: URL, root: URL) -> Bool {
        let rootPath = root.path
        let path = url.path
        return path == rootPath || path.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    /// The canonical form of an existing path: absolute, symlinks resolved.
    ///
    /// Uses `realpath(3)` rather than `URL.resolvingSymlinksInPath()` or
    /// `standardizedFileURL`, which both strip a leading `/private` and would
    /// make `/private/var/…` (returned by directory enumeration) and `/var/…`
    /// compare as different trees.
    static func canonical(_ url: URL) -> URL {
        guard let resolved = url.withUnsafeFileSystemRepresentation({ path in path.flatMap { realpath($0, nil) } }) else {
            return url.standardizedFileURL
        }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: url.hasDirectoryPath)
    }

    /// Resolves symlinks in the longest existing prefix of `url`, then
    /// re-appends the components that do not exist yet.
    private static func resolveExisting(_ url: URL) -> URL {
        var existing = url
        var missing: [String] = []
        while !FileManager.default.fileExists(atPath: existing.path), existing.path != "/" {
            missing.insert(existing.lastPathComponent, at: 0)
            existing.deleteLastPathComponent()
        }
        // No `standardizedFileURL` here: it would strip `/private` again.
        // `realpath` output is already standard and `missing` holds plain names.
        var resolved = canonical(existing)
        for component in missing {
            resolved.append(path: component)
        }
        return resolved
    }
}
