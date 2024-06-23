const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    // .{ .cpu_arch = .x86, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    for (targets) |t| {
        const exe = b.addExecutable(.{
            .name = "G-MemZ",
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(t),
            .optimize = .ReleaseSmall,
        });

        const target_output = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = t.zigTriple(b.allocator) catch "unknown",
                },
            },
        });

        b.getInstallStep().dependOn(&target_output.step);
    }
}
