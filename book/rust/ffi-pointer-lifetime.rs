// Rust's raw `*const AppInfo` carries no lifetime, so bindings such as ash give their create-info
// structs one (`InstanceCreateInfo<'a>`): the field borrows the record exactly as a reference does.
#[repr(C)]
struct AppInfo {
    api_version: u32,
    flags: u32,
}
#[repr(C)]
struct CreateInfo<'a> {
    s_type: u32,
    pad: u32,
    p_app: &'a AppInfo,
    count: u32,
}

fn main() {
    let mut app = AppInfo { api_version: 1, flags: 0 };
    let info = CreateInfo { s_type: 0, pad: 0, p_app: &app, count: 7 };
    app = AppInfo { api_version: 2, flags: 0 }; // info still points at the old app below.
    println!("{}", info.p_app.api_version + info.count + info.s_type + info.pad + app.flags);
}
