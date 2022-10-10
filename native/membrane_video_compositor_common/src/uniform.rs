use std::marker::PhantomData;

use wgpu::util::DeviceExt;

use crate::BindGroupAttachment;

pub struct Uniform<T: bytemuck::Pod> {
    buffer: wgpu::Buffer,
    _phantom: PhantomData<*const T>,
}

impl<T: bytemuck::Pod> Uniform<T> {
    pub fn new(device: &wgpu::Device) -> Uniform<T> {
        let buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some(concat!("uniform buffer <", stringify!(T), ">")),
            mapped_at_creation: false,
            size: std::mem::size_of::<T>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        Self {
            buffer,
            _phantom: PhantomData,
        }
    }

    pub fn new_with_data(device: &wgpu::Device, data: &T) -> Uniform<T> {
        let buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some(concat!("uniform buffer <", stringify!(T), ">")),
            contents: bytemuck::cast_slice(std::slice::from_ref(data)),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        Self {
            buffer,
            _phantom: PhantomData,
        }
    }

    pub fn upload(&self, queue: &wgpu::Queue, data: &T) {
        queue.write_buffer(
            &self.buffer,
            0,
            bytemuck::cast_slice(std::slice::from_ref(data)),
        )
    }
}

impl<T: bytemuck::Pod> BindGroupAttachment for Uniform<T> {
    fn binding_type() -> wgpu::BindingType {
        wgpu::BindingType::Buffer {
            ty: wgpu::BufferBindingType::Uniform,
            has_dynamic_offset: false,
            min_binding_size: std::num::NonZeroU64::new(std::mem::size_of::<T>() as u64),
        }
    }

    fn binding_resource(&self) -> wgpu::BindingResource {
        wgpu::BindingResource::Buffer(wgpu::BufferBinding {
            buffer: &self.buffer,
            offset: 0,
            size: None,
        })
    }
}

#[cfg(test)]
mod tests {
    use crate::test_utils;

    use super::*;

    #[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
    #[repr(C)]
    struct TestStruct {
        data: [u64; 8],
    }

    #[test]
    #[ignore]
    fn create_and_upload_single_struct() {
        let (device, _) = test_utils::initialize_wgpu();

        let _buffer = Uniform::new_with_data(&device, &TestStruct { data: [0; 8] });
    }

    #[test]
    #[ignore]
    fn create_and_upload_array() {
        let (device, _) = test_utils::initialize_wgpu();

        let _buffer = Uniform::new_with_data(
            &device,
            &[TestStruct { data: [42; 8] }, TestStruct { data: [21; 8] }],
        );
    }
}
