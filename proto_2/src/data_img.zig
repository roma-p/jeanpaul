const data_color = @import("data_color.zig");
const maths_mat = @import("maths_mat.zig");

/// axis are:
///   Y
///  ^
///  |    X
/// O --->
pub const Img = maths_mat.Matrix(data_color.Color);
