const std = @import("std.zig");
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

fn expectExpr(p: *Parse) !Node.Index {
    return try p.parseExpr()! // orelse return p.fail(.expected_expr);
}

fn eatToken(p: *Parse, tag: Token.Tag)?TokenIndex {
    return if (p.tokenTag(p.tok_i) == tag) p.nextToekn() else null;
}
