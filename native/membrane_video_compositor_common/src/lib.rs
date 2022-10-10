pub use bytemuck;
pub use wgpu;

pub mod errors;
#[cfg(test)]
pub mod test_utils;
pub mod textures;

/// This trait provides a common way to provide `BindingType` and `BindingResource` for various abstractions over wgpu types  
pub trait BindGroupAttachment {
    fn binding_type() -> wgpu::BindingType;
    fn binding_resource(&self) -> wgpu::BindingResource;
}
