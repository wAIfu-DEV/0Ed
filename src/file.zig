const std = @import("std");

const nfd = @import("nfd");

const types = @import("types.zig");
const state = @import("global_state.zig");
const toCodepoint = @import("char_to_codepoint.zig");

// Function called by button callback, cannot return error
pub fn openFileDialog() void {
    // TODO: default path should be CWD
    if (nfd.openFileDialog(null, null)) |path| {
        if (path) |nonNullPath| {
            openFile(nonNullPath) catch |err| {
                std.log.err("Error when trying to open file: {s} {any}", .{ nonNullPath, err });
            };
        }
    } else |err| {
        // TODO: Show error modal when implemented
        std.log.err("Error with openFileDialog: {any}", .{err});
    }
}

pub fn addOpenedFile(file: types.OpenedFile) void {
    if (state.openedFiles.append(file)) |_| {
        state.currentlyDisplayedFileIdx = state.openedFiles.items.len - 1;
    } else |err| {
        std.log.err("Error with addOpenedFile: {any}", .{err});
    }
}

fn writeFile(file: *types.OpenedFile) !void {
    if (file.path == null) return;

    const maybeFile = std.fs.cwd().openFile(
        file.path.?,
        std.fs.File.OpenFlags{ .mode = .write_only },
    );

    var f: std.fs.File = undefined;

    if (maybeFile) |ff| {
        f = ff;
    } else |err| {
        std.log.err("Failed to open file for saving: {s}; Error: {any}", .{ file.path.?, err });
        return error.OpenError;
    }
    defer f.close();

    var bufWriter = std.io.bufferedWriter(f.writer());

    for (file.lines.items) |line| {
        for (line.items) |codepoint| {
            var utfBuf: [4]u8 = undefined;
            const seqLen: usize = @intCast(try std.unicode.utf8Encode(@intCast(codepoint), &utfBuf));
            _ = try bufWriter.write(utfBuf[0..seqLen]);
        }
        const newLine = [1]u8{'\n'};
        _ = try bufWriter.write(&newLine);
    }

    try bufWriter.flush();
}

pub fn saveFileAs() void {
    if (state.openedFiles.items.len == 0) return;

    var currentFile = state.openedFiles.items[state.currentlyDisplayedFileIdx];

    if (nfd.saveFileDialog(null, null)) |path| {
        currentFile.path = path;
        writeFile(&currentFile) catch |err| {
            std.log.err("Error with writeFile: {any}", .{err});
        };
    } else |err| {
        std.log.err("Error with saveFileDialog: {any}", .{err});
    }
}

pub fn saveFile() void {
    if (state.openedFiles.items.len == 0) return;

    var currentFile = state.openedFiles.items[state.currentlyDisplayedFileIdx];

    if (currentFile.path) |_| {
        writeFile(&currentFile) catch |err| {
            std.log.err("Error with writeFile: {any}", .{err});
        };
    } else {
        saveFileAs();
    }
}

// Function called by button callback, cannot return error
pub fn newFile() void {
    state.editorScroll = .{ .x = 0, .y = 0 };

    var openedFile = types.OpenedFile{
        .path = null,
        .name = "NewFile.txt",
        .lines = std.ArrayList(std.ArrayList(i32)).init(state.allocator),
        .cursorPos = types.CursorPosition{
            .start = .{
                .column = 0,
                .line = 0,
            },
            .end = null,
            .dragOrigin = null,
        },
    };

    // Add 1 empty line to the file
    if (openedFile.lines.append(std.ArrayList(i32).init(state.allocator))) |_| {} else |err| {
        std.log.err("Error with newFile: {any}", .{err});
    }

    addOpenedFile(openedFile);
}

pub fn openFile(filePath: []const u8) error{ OpenError, ReadError, OutOfMemory }!void {
    const maxFileSize = @as(usize, 0) -% 1;

    state.editorScroll = .{ .x = 0, .y = 0 };

    var openedFile = types.OpenedFile{
        .path = filePath,
        .name = std.fs.path.basename(filePath),
        .lines = std.ArrayList(std.ArrayList(i32)).init(state.allocator),
        .cursorPos = types.CursorPosition{
            .start = .{
                .column = 0,
                .line = 0,
            },
            .end = null,
            .dragOrigin = null,
        },
    };

    const maybeFile = std.fs.cwd().openFile(
        filePath,
        std.fs.File.OpenFlags{},
    );

    var f: std.fs.File = undefined;

    if (maybeFile) |file| {
        f = file;
    } else |err| {
        std.log.err("Failed to open file: {s}; Error: {any}", .{ filePath, err });
        return error.OpenError;
    }

    defer f.close();

    const fReader = f.reader();

    std.log.info("Reading file: {s}", .{filePath});

    while (fReader.readUntilDelimiterOrEofAlloc(
        state.allocator,
        '\n',
        maxFileSize,
    )) |maybeLine| {
        if (maybeLine) |line| {
            defer state.allocator.free(line);

            const codepoints = try toCodepoint.charToCodepoint(
                state.allocator,
                line,
            );

            defer codepoints.deinit();

            const lineList = std.ArrayList(types.CodePoint).init(state.allocator);
            try openedFile.lines.append(lineList);
            var lastList: *std.ArrayList(types.CodePoint) = &openedFile.lines.items[openedFile.lines.items.len - 1];

            try lastList.appendSlice(codepoints.items);
        } else {
            break;
        }
    } else |err| {
        if (err != error.EndOfStream) {
            std.log.err("Failed to read file: {s}; Error: {any}", .{ filePath, err });
            return error.ReadError;
        }
    }

    if (openedFile.lines.items.len == 0) {
        // Add 1 empty line to the file
        if (openedFile.lines.append(std.ArrayList(i32).init(state.allocator))) |_| {} else |err| {
            std.log.err("Error with openFile: {any}", .{err});
        }
    }

    addOpenedFile(openedFile);
}
