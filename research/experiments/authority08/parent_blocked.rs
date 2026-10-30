fn main() {
    let mut data = 1;
    let parent = &mut data;
    let child = &mut *parent;
    *parent = 2;
    *child += 10;
}
