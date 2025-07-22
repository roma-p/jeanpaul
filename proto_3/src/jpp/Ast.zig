const std = @import("std");
const Allocator = std.mem.Allocator;

const _tokenizer = @import("tokenizer.zig");
const Tokenizer = _tokenizer.Tokenizer;
pub const Token = _tokenizer.Token;

const Parse = @import("Parse.zig");

const Ast = @This();

source: [:0]const u8,

tokens: TokenList.Slice,
nodes: NodeList.Slice,
extra_data: []u32,

errors: []const Error,

pub const ByteOffset = u32;
pub const TokenIndex = u32;
pub const ExtraIndex = u32;

pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: ByteOffset,
});
pub const NodeList = std.MultiArrayList(Node);

pub const Node = struct {
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    pub const Index = enum(u32) {
        root = 0,
        _,
    };

    pub const ExtraRange = struct {
        start: ExtraIndex,
        end: ExtraIndex,
    };

    pub const Tag = enum {
        // root index in NodeList will always be Index.root
        // main_token is first token idx of the file.
        // (does not include hasbang)
        // Data is extra_range: all children nodes idx of root.
        root,
    };

    pub const Data = union {
        node_and_node: struct { Index, Index },
        node_and_extra: struct { Index, ExtraIndex },
        extra_and_node: struct { ExtraIndex, Index },
        token_and_node: struct { TokenIndex, Index },
        node_and_token: struct { Index, TokenIndex },
        extra_range: ExtraRange,
    };
};

pub const Error = struct {
    tag: Tag,
    token: TokenIndex,
    pub const Tag = enum {
        missing_closing_brace,
    };
};

pub fn parse(gpa: Allocator, source: [:0]const u8) !Ast {
    var tokens = Ast.TokenList{};
    defer tokens.deinit(gpa);

    // TODO: empirically: what is ratio of file len / token number? starting by 8 like zig compiler.
    const estimated_token_count = source.len / 8;
    try tokens.ensureTotalCapacity(gpa, estimated_token_count);

    var tokenizer = Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(gpa, .{
            .tag = token.tag,
            .start = @intCast(token.loc.start),
        });
        if (token.tag == .eof) break;
    }

    var parser: Parse = .{
        .source = source,
        .gpa = gpa,
        .tokens = tokens.slice(),
        .nodes = .{},
        .extra_data = .{},
        .scratch = .{},
        .tok_i = 0,
    };
    // // defer parser.errors.deinit();
    defer parser.nodes.deinit(gpa);
    defer parser.extra_data.deinit(gpa);
    defer parser.scratch.deinit(gpa);

    // SAME...
    const estimated_node_count = (tokens.len + 2) / 2;
    try parser.nodes.ensureTotalCapacity(gpa, estimated_node_count);

    try parser.parseRoot();

    const extra_data = try parser.extra_data.toOwnedSlice(gpa);
    errdefer gpa.free(extra_data);

    // // const errors = try parser.errors.toOwnedSlice(gpa);
    // // errdefer gpa.free(errors);
    //
    return Ast{
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extra_data = extra_data,
        .errors = undefined, // TODO
    };
}

pub fn deinit(ast: *Ast, gpa: Allocator) void {
    ast.tokens.deinit(gpa);
    ast.nodes.deinit(gpa);
    gpa.free(ast.extra_data);
    // gpa.free(ast.errors);
    ast.* = undefined;
}

test "lul" {
    _ = Parse;
}
