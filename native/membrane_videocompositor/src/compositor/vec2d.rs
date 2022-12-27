use std::fmt::Display;

#[derive(Debug, Clone, Copy)]
#[repr(C)]
/// A point in 2D space
pub struct Vec2d<T> {
    pub x: T,
    pub y: T,
}

impl<T: Display> Display for Vec2d<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}
