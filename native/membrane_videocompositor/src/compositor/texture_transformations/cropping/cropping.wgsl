struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) texture_coords: vec2<f32>
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texture_coords: vec2<f32>,
}

struct CroppingUnifrom{
    crop_matrix: mat4x4<f32>,
    top_left_corner_crop_x: f32,
    top_left_corner_crop_y: f32,
    crop_width: f32,
    crop_height: f32,
    transform_position: u32,
}

@group(0) @binding(0)
var texture: texture_2d<f32>;

@group(1) @binding(0)
var sampler_: sampler;

@group(2) @binding(0)
var<uniform> cropping: CroppingUnifrom;

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    output.position = vec4<f32>(input.position, 1.0);
    output.texture_coords = (cropping.crop_matrix * vec4<f32>(input.texture_coords, 0.0, 1.0)).xy;

    return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    return textureSample(texture, sampler_, input.texture_coords);
}
