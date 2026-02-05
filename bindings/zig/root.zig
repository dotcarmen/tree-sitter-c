const tree_sitter = @import("tree-sitter");

extern fn tree_sitter_c() tree_sitter.LanguageFn;

pub const language = tree_sitter_c;

test "can load grammar" {
    const parser: *tree_sitter.Parser = .create();
    defer parser.destroy();

    const lang = language();
    defer lang.destroy();
    try parser.setLanguage(lang);

    const testing = @import("std").testing;
    try testing.expectEqual(lang, parser.getLanguage());
}
