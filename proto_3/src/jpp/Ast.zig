const std = @import("std.zig");
const Allocator = std.mem.Allocator;

const _tokenizer = @import("tokenizer.zig");
const Tokenizer = _tokenizer.Tokenizer;
const Token = _tokenizer.Token;

const Parse = @import("Parse.zig");

const Ast = @This();

source: [:0]const u8,
tokens: TokenList.Slice,
nodes: NodeList.Slice,


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
    
    pub const Tag = enum {
        root,
    };

    pub const Data = union{
        node_and_node: struct {Index, Index},
        node_and_extra: struct {Index, ExtraIndex},
        extra_and_node: struct {ExtraIndex, Index},
        token_and_node: struct {TokenIndex, Index},
        node_and_token: struct {Index, TokenIndex},
    };
};

pub fn parse(gpa: Allocator, source: [:0]const u8) !Ast{
    var tokens = Ast.TokenList{};
    defer tokens.deinit(gpa);

    // TODO: empirically: what is ratio of file len / token number? starting by 8 like zig compiler.
    const estimated_token_count = source.len / 8;
    try tokens.ensureTotalCapacity(gpa, estimated_token_count);

    var tokenizer = Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(gpa,
            .{
                .tag = token.tag,
                .start=@intCast(token.loc.start),
            }
        );
        if (token.tag == .eof) break;
    }

    var parser: Parse = .{
        .source = source,
        .gpa = gpa,
        .tokens = tokens.slice(),
        .nodes = {},
        .extra_data = .{},
        .scratch = {},
        .tok_i = 0,
    };
    // defer parser.errors.deinit();
    defer parser.nodes.deinit(gpa);
    defer parser.extra_data.deinit(gpa);
    defer parser.scratch.deinit(gpa);

    // SAME...
    const estimated_node_count = (tokens.len + 2) / 2;
    try parser.nodes.ensureTotalCapacity(gpa, estimated_node_count);
}
