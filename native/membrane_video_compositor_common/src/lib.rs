#![deny(unsafe_op_in_unsafe_fn)]

pub mod elixir_transfer;
pub mod plugins;
pub mod texture;

pub extern crate wgpu;

pub struct WgpuContext {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
}
