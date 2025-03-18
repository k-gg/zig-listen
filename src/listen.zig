const std = @import("std");
const net = std.net;
const posix = std.posix;

// A Listener is a generic network listener for stream-oriented protocols.
//
// Multiple threads may invoke methods on a Listener simultaneously.
const Listener = struct {
    _network: []const u8,
    _string: []const u8,
    _listener: posix.socket_t,

    // close closes the listener.
    // Any blocked Accept operations will be unblocked and return errors.
    pub fn close(self: *Listener) void {
        posix.close(self._listener);
    }

    /// addr returns the listener's network address.
    pub fn addr(self: *Listener) Addr {
        return .{
            .network = self._network,
            .string = self._string,
        };
    }

    /// accept waits for and returns the next connection to the listener.
    pub fn accept(self: *Listener) !Conn {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = try posix.accept(self._listener, &client_address.any, &client_address_len, 0);

        const conn = Conn{
            ._socket = socket,
        };

        return conn;
    }
};

const Conn = struct {
    _socket: posix.socket_t,

    pub fn read(self: *Conn, b: []u8) !u8 {
        const n = try posix.read(self._socket, b);

        return n;
    }

    pub fn write(self: *Conn, b: []u8) !u8 {
        const n = try posix.write(self._socket, b);
        return n;
    }

    pub fn close(self: *Conn) void {
        posix.close(self._socket);
    }
};

const Addr = struct {
    // name of the network (for example, "tcp", "udp")
    network: []const u8,

    // string form of address (for example, "192.0.2.1:25", "[2001:db8::1]:80)
    string: []const u8,
};

pub fn listen(sock_type: Sock_Type, port: u8, config: listen_config) !Listener {
    const address = try net.Address.parseIp("127.0.0.1", port);

    const tpe: u32 = switch (sock_type) {
        Sock_Type.TCP => posix.SOCK.STREAM,
        Sock_Type.UDP => posix.SOCK.DGRAM,
    };
    const protocol: u32 = switch (sock_type) {
        Sock_Type.TCP => posix.IPPROTO.TCP,
        Sock_Type.UDP => posix.IPPROTO.UDP,
    };
    const listener = try posix.socket(address.any.family, tpe, protocol);

    _ = config;
    //    if (config.reuse_address.?) {
    //        try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    //    }

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    const response = Listener{
        ._listener = listener,
        ._network = sock_type.string(),
        // TODO: assign correct value to ._string
        ._string = "",
    };

    return response;
}

const listen_config = struct {
    // backlog for posix.listen
    backlog: ?u31,

    reuse_address: ?bool,
};

pub const Sock_Type = enum {
    TCP,
    UDP,

    pub fn string(self: *Sock_Type) []const u8 {
        switch (self) {
            Sock_Type.TCP => return "tcp",
            Sock_Type.UDP => return "udp",
        }
    }
};

test "listen" {
    const ln = try listen(.TCP, 3000, .{});
    while (true) {
        const conn = try ln.accept();
        _ = try conn.write("hello\n");
    }
}
