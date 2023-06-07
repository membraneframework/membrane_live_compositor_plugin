use membrane_video_compositor_common::{wgpu, WgpuContext};

pub fn create_new_wgpu_context() -> WgpuContext {
    let instance = wgpu::Instance::new(wgpu::Backends::all());
    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        compatible_surface: None,
        force_fallback_adapter: false,
        power_preference: wgpu::PowerPreference::HighPerformance,
    }))
    .unwrap();

    let (device, queue) = pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            label: Some("Membrane Video Compositor's GPU :^)"),
            ..Default::default()
        },
        None,
    ))
    .unwrap();

    WgpuContext { device, queue }
}
