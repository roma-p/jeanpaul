const std = @import("std");

pub const HandleCamera = struct {
    idx: usize,
};

pub const HandleShape = struct {
    idx: usize,
};

pub const HandleEnv = struct {
    idx: usize,
};

pub const HandleObjectName = struct {
    idx: usize,
};

pub const HandleTMatrix = struct {
    idx: usize,
};

pub const HandleMaterial = struct {
    idx: usize,
};

pub const HandleObjectWithTMatrixEnum = union(enum) {
    HandleCamera: HandleCamera,
    HandleShape: HandleShape,
};

pub const HandleHRayHittableObjects = union(enum) {
    HandleShape: HandleShape,
    HandleEnv: HandleEnv,
};
