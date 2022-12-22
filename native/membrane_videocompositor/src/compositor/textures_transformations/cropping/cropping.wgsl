struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) texture_coords: vec2<f32>
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texture_coords: vec2<f32>,
}

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    output.position = vec4<f32>(input.position, 1.0);
    output.texture_coords = input.texture_coords;

    return output;
}

struct CroppingUnifrom{
    top_left_corner_crop_x: f32,
    top_left_corner_crop_y: f32,
    crop_width: f32,
    crop_height: f32
}

@group(0) @binding(0)
var texture: texture_2d<f32>;

@group(1) @binding(0)
var sampler_: sampler;

@group(2) @binding(0)
var<uniform> cropping: CroppingUnifrom;


@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    let colour = textureSample(texture, sampler_, input.texture_coords);

    if (
        (input.texture_coords.x < cropping.top_left_corner_crop_x) || 
        (input.texture_coords.y < cropping.top_left_corner_crop_y) ||
        (input.texture_coords.x > cropping.top_left_corner_crop_x + cropping.crop_width) || 
        (input.texture_coords.y > cropping.top_left_corner_crop_y + cropping.crop_height)
    ) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    } else {
        return colour;
    }
}
