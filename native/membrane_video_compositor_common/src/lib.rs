#![deny(unsafe_op_in_unsafe_fn)]

pub mod elixir_transfer;
pub mod plugins;

pub extern crate wgpu;

pub struct WgpuCtx {
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
}
