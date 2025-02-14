const std = @import("std");
const rl = @import("raylib");

pub const Recti32 = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const Vec2i32 = struct {
    x: i32,
    y: i32,
};

pub const TextPos = struct {
    column: i32,
    line: i32,
};

pub const CodePoint = i32;

pub const KeyChar = struct {
    key: rl.KeyboardKey,
    char: CodePoint,
};

pub const PressedKeyState = struct {
    keyChar: KeyChar,
    pressedFrames: usize,
};

pub const CursorPosition = struct {
    start: TextPos,
    end: ?TextPos,
    dragOrigin: ?TextPos,
};

pub const OpenedFile = struct {
    name: [:0]const u8,
    path: ?[:0]const u8,
    lines: std.ArrayList(std.ArrayList(CodePoint)),
    cursorPos: CursorPosition,
    scroll: rl.Vector2,
};

pub const FsType = enum(u8) {
    Folder,
    File,
};

pub const FileSystemTree = struct {
    name: [:0]const u8,
    path: [:0]const u8,
    children: std.ArrayList(FileSystemTree),
    type: FsType,
    expanded: bool,
};

pub const TopBarMenu = enum(u8) {
    None = 0,
    File,
    Edit,
};

pub const MenuItem = struct {
    name: [:0]const u8,
    callback: *const fn () void,
};

pub const Menu = struct {
    origin: Vec2i32,
    items: []MenuItem,
};

pub const Rgb = [3]u8;

pub const ExprColor = struct {
    name: []const u8,
    rgb: Rgb,
};

pub const Style = struct {
    name: []const u8,
    expr: []const u8,
};

pub const MatchedStyle = struct {
    style: ?Style,
    priority: i32,
    start: i32,
    end: i32,
};
