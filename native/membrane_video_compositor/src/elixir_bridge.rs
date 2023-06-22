use crate::compositor;
use crate::elixir_bridge::elixir_structs::*;
use membrane_video_compositor_common::elixir_transfer::{
    LayoutElixirPacket, StructElixirPacket, TransformationElixirPacket,
};
use membrane_video_compositor_common::{elixir_transfer, WgpuCtx};
use rustler::ResourceArc;

pub mod elixir_structs;
mod scene_validation;

pub mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
pub fn test_scene_deserialization(obj: Scene) -> Result<rustler::Atom, rustler::Error> {
    let _scene: crate::scene::Scene = obj.try_into()?;

    Ok(atoms::ok())
}

#[rustler::nif]
pub fn init() -> Result<(rustler::Atom, rustler::ResourceArc<compositor::State>), rustler::Error> {
    Ok((atoms::ok(), ResourceArc::new(compositor::State::new())))
}

#[rustler::nif]
pub fn wgpu_ctx(
    state: ResourceArc<compositor::State>,
) -> elixir_transfer::StructElixirPacket<WgpuCtx> {
    let state = state.lock().unwrap();
    StructElixirPacket::<WgpuCtx>::encode_arc(state.wgpu_ctx())
}

#[rustler::nif]
pub fn register_transformation(
    state: ResourceArc<compositor::State>,
    transformation: TransformationElixirPacket,
) -> Result<rustler::Atom, rustler::Error> {
    let mut state = state.lock().unwrap();
    state.register_transformation(unsafe { transformation.decode() })?;
    Ok(atoms::ok())
}

#[rustler::nif]
pub fn register_layout(
    state: ResourceArc<compositor::State>,
    layout: LayoutElixirPacket,
) -> Result<rustler::Atom, rustler::Error> {
    let mut state = state.lock().unwrap();
    state.register_layout(unsafe { layout.decode() })?;
    Ok(atoms::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn mock_transformation(ctx: StructElixirPacket<WgpuCtx>) -> TransformationElixirPacket {
    use membrane_video_compositor_common::plugins::transformation::Transformation;

    let ctx = unsafe { ctx.decode() };
    unsafe { TransformationElixirPacket::encode(compositor::MockTransformation::new(ctx)) }
}

#[rustfmt::skip]
rustler::init!(
    "Elixir.Membrane.VideoCompositor.Wgpu.Native",
    [
        test_scene_deserialization,
        init,
        wgpu_ctx,
        register_transformation,
        register_layout,
        mock_transformation,
    ],
    load = |env, _| {
        rustler::resource!(crate::compositor::State, env);

        true
    }
);
