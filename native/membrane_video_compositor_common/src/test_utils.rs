pub fn initialize_wgpu() -> (wgpu::Device, wgpu::Queue) {
    let instance = wgpu::Instance::new(wgpu::Backends::all());
    let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
        compatible_surface: None,
        force_fallback_adapter: false,
        power_preference: wgpu::PowerPreference::HighPerformance,
    }))
    .unwrap();

    pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            label: Some("testing device"),
            features: wgpu::Features::empty(),
            limits: wgpu::Limits::default(),
        },
        None,
    ))
    .unwrap()
}
