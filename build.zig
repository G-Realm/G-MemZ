const std = @import("std");
const builtin = @import("builtin");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .x86, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

pub fn build(b: *std.Build) void {
    // Architecture specific.
    const macos_universal_cmd = b.addSystemCommand(&.{ "lipo", "-create", "-output" });
    const macos_universal = macos_universal_cmd.addOutputFileArg("universal_app");

    for (targets) |t| {
        const exe = b.addExecutable(.{
            .name = "G-MemZ",
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(t),
            .optimize = .ReleaseSmall,
        });

        exe.addIncludePath(b.path("src"));

        const target_output = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = t.zigTriple(b.allocator) catch "unknown",
                },
            },
        });

        b.getInstallStep().dependOn(&target_output.step);

        if (t.os_tag == .macos) {
            macos_universal_cmd.addArtifactArg(exe);
        }
    }

    // Universal.
    if (builtin.os.tag == .macos) {
        const universal_output = b.addInstallFile(macos_universal, "universal-macos/universal_app");

        b.getInstallStep().dependOn(&universal_output.step);
    }
}
