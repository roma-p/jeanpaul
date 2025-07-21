const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "FILE_SECTION", .keyword_file_section },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        identifier,
        string_literal,
        number_literal,
        hashbang,
        keyword_file_section, // ??? remove?
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        equal,
        comma,
        period,
        eof,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .string_literal,
                .number_literal,
                => null,
                .hashbang => "#!",
                .read_tag => ">>>",
                .equal => "=",
                .equal => ",",
                .period => ".",
                .l_paren => "(",
                .r_paren => ")",
                .l_brace => "{",
                .r_brace => "}",
                .keyword_file_section => "FILE_SECTION",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
                .identifier => "an identifier",
                .string_literal => "a string literal",
                .number_literal => "a number literal",
                .hashbang => "hashbang",
                .comment => "a comment",
                else => unreachable,
            };
        }
    };
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    const State = enum {
        start,
        string_literal,
        identifier,
        invalid,
        line_comment_start,
        line_comment,
    };

    pub fn next(self: *Tokenizer) Token {
        var result: Token = .{ .tag = undefined, .loc = .{
            .start = self.index,
            .end = undefined,
        } };
        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        if (self.index == self.buffer.len) {
                            return .{
                                .tag = .eof,
                                .loc = .{
                                    .start = self.index,
                                    .end = self.index,
                                },
                            };
                        }
                    }
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    result.loc.start = self.index;
                    continue :state .start;
                },
                '"' => {
                    result.tag = .string_literal;
                    continue :state .string_literal;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    result.tag = .identifier;
                    continue :state .identifier;
                },
                // '0'...'9' => {
                //     result.tag = .number_literal;
                //     self.index += 1;
                //     continue :state .int;
                // },
                '(' => {
                    result.tag = .l_paren;
                    self.index += 1;
                },
                ')' => {
                    result.tag = .r_paren;
                    self.index += 1;
                },
                '{' => {
                    result.tag = .l_brace;
                    self.index += 1;
                },
                '}' => {
                    result.tag = .r_brace;
                    self.index += 1;
                },
                '=' => {
                    result.tag = .equal;
                    self.index += 1;
                },
                ',' => {
                    result.tag = .comma;
                    self.index += 1;
                },
                '/' => {
                    continue :state .line_comment_start;
                },
                // '.' => continue :state .period,
                else => continue :state .invalid,
            },
            .identifier => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                    else => {},
                }
            },
            .string_literal => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    // missing end
                    '"' => self.index += 1,
                    else => continue :state .string_literal,
                }
            },
            .line_comment_start => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '/' => continue :state .line_comment,
                    else => continue :state .invalid,
                }
            },

            .line_comment => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },
                    else => continue :state .line_comment,
                }
            },
            .invalid => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    } else {
                        continue :state .invalid;
                    },
                    '\n' => result.tag = .invalid,
                    else => continue :state .invalid,
                }
            },
        }
        result.loc.end = self.index;
        return result;
    }
};

test "tokeniser simple struct" {
    var tokeniser = Tokenizer.init("Scene{ name=\"prout\"}");

    const t1 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.identifier, t1.tag);
    try std.testing.expectEqual(0, t1.loc.start);
    try std.testing.expectEqual(5, t1.loc.end);

    const t2 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.l_brace, t2.tag);
    try std.testing.expectEqual(5, t2.loc.start);
    try std.testing.expectEqual(6, t2.loc.end);

    const t3 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.identifier, t3.tag);
    try std.testing.expectEqual(7, t3.loc.start);
    try std.testing.expectEqual(11, t3.loc.end);

    const t4 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.equal, t4.tag);
    try std.testing.expectEqual(11, t4.loc.start);
    try std.testing.expectEqual(12, t4.loc.end);

    const t5 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.string_literal, t5.tag);
    try std.testing.expectEqual(12, t5.loc.start);
    try std.testing.expectEqual(19, t5.loc.end);

    const t6 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.r_brace, t6.tag);
    try std.testing.expectEqual(19, t6.loc.start);
    try std.testing.expectEqual(20, t6.loc.end);

    const t7 = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.eof, t7.tag);
    try std.testing.expectEqual(20, t7.loc.start);
    try std.testing.expectEqual(20, t7.loc.end);
}

fn testTokeniser(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokeniser = Tokenizer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokeniser.next();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
    const last_token = tokeniser.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}

test "testTokeniser utils" {
    try testTokeniser(
        "Scene{ name=\"prout\"}",
        &.{
            .identifier,
            .l_brace,
            .identifier,
            .equal,
            .string_literal,
            .r_brace,
        },
    );
}

test "testTokeniser simple struct at end of line" {
    try testTokeniser(
        "Scene{ name=\"prout\"} // some comment to be ignored",
        &.{
            .identifier,
            .l_brace,
            .identifier,
            .equal,
            .string_literal,
            .r_brace,
        },
    );
}

test "testTokeniser simple struct but multiline." {
    try testTokeniser(
        \\Scene{
        \\  name="prout", // best name ever
        \\  from="tadam" // best name ever
        \\}
    ,
        &.{
            .identifier,
            .l_brace,
            .identifier,
            .equal,
            .string_literal,
            .comma,
            .identifier,
            .equal,
            .string_literal,
            .r_brace,
        },
    );
}

test "testTokeniser simple struct at end of line and return of line" {
    try testTokeniser(
        "Scene{ name=\"prout\"} // some comment to be ignored\nScene{}",
        &.{
            .identifier,
            .l_brace,
            .identifier,
            .equal,
            .string_literal,
            .r_brace,
            .identifier,
            .l_brace,
            .r_brace,
        },
    );
}
