const std = @import("std");

pub const Token = struct {

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

    pub const Tag = enum{
        invalid,
        identifier,
        string_literal,
        number_literal,
        hashbang,
        comment,
        keyword_file_section, // ??? remove?
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        equal,
        comma,
        period,

        pub fn lexeme(tag: Tag) ?[]const u8{
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
                else => unreachable,
            };
        }

    };

};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn init(buffer: [:0]const u8) void {
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    const State = enum{
        start,
        string_literal,
        identifier,
    };

    pub fn next(self: *Tokenizer) Token {
        var result: Token = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            }
        };
        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                // TODO: EOF
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    result.loc.start = self.index;
                    continue : state .start;
                },
                '"' => {
                    result.tag = .string_literal;
                    continue: state .string_literal;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    result.tag = .identifier;
                    continue :state .identifier;
                },
                '0'...'9' => {
                    result.tag = .number_literal;
                    self.index +=1;
                    continue :state .int;
                },
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
                '.' => continue :state .period,
            },
            .identifier => {
                self.index += 1;
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                else => {},
            },
            .string_literal => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    // missing end
                    '"' => self.index +1
                    else => continue :state .string_literal,
                }
            },
        }
        result.loc.end = self.index;
        return result;
    }
};
