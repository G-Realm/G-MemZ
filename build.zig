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

        if (t.os_tag == .macos) {
            // Codesign with entitlements.
            const sign_cmd = b.addSystemCommand(&.{
                "codesign", "--force", "--entitlements", "Entitlements.plist", "--sign", "-",
            });

            sign_cmd.addArtifactArg(exe);

            // Run the codesign command after the target output is created.
            target_output.step.dependOn(&sign_cmd.step);

            // Add the target output to the universal command.
            macos_universal_cmd.addArtifactArg(exe);
        }

        b.getInstallStep().dependOn(&target_output.step);
    }

    // Universal.
    if (builtin.os.tag == .macos) {
        const universal_output = b.addInstallFile(macos_universal, "universal-macos/G-MemZ");

        b.getInstallStep().dependOn(&universal_output.step);
    }
}
