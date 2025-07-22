const std = @import("std");
const Allocator = std.mem.Allocator;

const Ast = @import("Ast.zig");
const TokenIndex = Ast.TokenIndex;
const Node = Ast.Node;
const Token = Ast.Token;

const Parse = @This();

source: []const u8,
gpa: Allocator,
tokens: Ast.TokenList.Slice,
tok_i: TokenIndex,
// errors: std.ArrayListUnmanaged(AstErrors),
nodes: Ast.NodeList,
extra_data: std.ArrayListUnmanaged(u32),
scratch: std.ArrayListUnmanaged(Node.Index),

// fn expectExpr(p: *Parse) !Node.Index {
//     return try p.parseExpr()! // orelse return p.fail(.expected_expr);
// }
//
fn tokenTag(p: *const Parse, token_index: TokenIndex) Token.Tag {
    return p.tokens.items(.tag)[token_index];
}

fn eatToken(p: *Parse, tag: Token.Tag) ?TokenIndex {
    return if (p.tokenTag(p.tok_i) == tag) p.nextToken() else null;
}

fn nextToken(p: *Parse) TokenIndex {
    const result = p.tok_i;
    p.tok_i += 1;
    return result;
}

pub fn parseRoot(p: *Parse) !void {
    // Root node must be index 0.
    p.nodes.appendAssumeCapacity(.{
        .tag = .root,
        .main_token = 0,
        .data = undefined,
    });
    try p.parseRootScope();
    p.nodes.items(.data)[0] = .{ .extra_range = .{ .start = 0, .end = 0 } };
}

pub fn parseRootScope(p: *Parse) !void {
    switch (p.tokenTag(p.eatToken(.identifier).?)) {
        .identifier => {
            const t = p.eatToken(.l_brace);
            if (t == null) unreachable;
        },
        else => unreachable,
    }
}
