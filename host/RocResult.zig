pub fn RocResult(comptime T: type, comptime E: type) type {
    return extern struct {
        payload: RocResultPayload(T, E),
        tag: RocResultTag,

        pub fn isOk(self: @This()) bool {
            return (self.tag == RocResultTag.RocOk);
        }
    };
}

pub fn RocResultPayload(comptime T: type, comptime E: type) type {
    return extern union {
        ok: T,
        err: E,
    };
}

const RocResultTag = enum(u8) {
    RocErr = 0,
    RocOk = 1,
};
