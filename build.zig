const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const shared = b.option(bool, "build-shared", "Build a shared library") orelse true;
    const reuse_alloc = b.option(bool, "reuse-allocator", "Reuse the library allocator") orelse false;

    const library_name = "tree-sitter-c";

    const lib: *std.Build.Step.Compile = b.addLibrary(.{
        .name = library_name,
        .linkage = if (shared) .dynamic else .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .pic = if (shared) true else null,
        }),
    });

    lib.root_module.addCSourceFile(.{
        .file = b.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    if (fileExists(b, "src/scanner.c")) {
        lib.root_module.addCSourceFile(.{
            .file = b.path("src/scanner.c"),
            .flags = &.{"-std=c11"},
        });
    }

    if (reuse_alloc) {
        lib.root_module.addCMacro("TREE_SITTER_REUSE_ALLOCATOR", "");
    }
    if (optimize == .Debug) {
        lib.root_module.addCMacro("TREE_SITTER_DEBUG", "");
    }

    lib.root_module.addIncludePath(b.path("src"));

    b.installArtifact(lib);
    b.installFile("src/node-types.json", "node-types.json");

    if (fileExists(b, "queries")) {
        b.installDirectory(.{
            .source_dir = b.path("queries"),
            .install_dir = .prefix,
            .install_subdir = "queries",
            .include_extensions = &.{"scm"},
        });
    }

    const module = b.addModule(library_name, .{
        .root_source_file = b.path("bindings/zig/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkLibrary(lib);

    // only fetch tree-sitter dependency when this is the root module being built
    if (b.pkg_hash.len == 0) {
        if (b.lazyDependency("tree_sitter", .{})) |tree_sitter| {
            module.addImport("tree-sitter", tree_sitter.module("tree-sitter"));
        }
    }

    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

inline fn fileExists(b: *std.Build, filename: []const u8) bool {
    const dir = b.build_root.handle;
    dir.access(b.graph.io, filename, .{}) catch return false;
    return true;
}
