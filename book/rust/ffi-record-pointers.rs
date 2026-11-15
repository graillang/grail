// The Rust twin of examples/ffi-record-pointers.grl, linking the same C fixture. `#[repr(C)]`
// gives the layout, a field typed `*const AppInfo` is the `const struct app_info *`, and `&mut`
// is the `struct app_info *` the callee fills.
#[repr(C)]
struct AppInfo {
    api_version: u32,
    flags: u32,
}

#[repr(C)]
struct CreateInfo {
    s_type: u32,
    pad: u32,
    p_app: *const AppInfo,
    count: u32,
}

unsafe extern "C" {
    fn book_create(info: *const CreateInfo) -> i64;
    fn book_fill(app: *mut AppInfo) -> i64;
}

fn main() {
    let app = AppInfo {
        api_version: 1,
        flags: 0,
    };
    let info = CreateInfo {
        s_type: 0,
        pad: 0,
        p_app: &app,
        count: 7,
    };
    let created = unsafe { book_create(&info) };
    println!("{created}");

    let mut filled = AppInfo {
        api_version: 0,
        flags: 0,
    };
    let seen = unsafe { book_fill(&mut filled) };
    println!("{seen}");
    println!("{}", filled.api_version);
}
