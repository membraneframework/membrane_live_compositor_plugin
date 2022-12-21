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
    video_width: f32,
    video_height: f32,
    top_left_corner_crop: (f32, f32),
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
    let video_width = cropping.video_width;
    let video_height = cropping.video_height;
    let top_left_corner_crop = cropping.top_left_corner_crop;
    let crop_width = cropping.crop_width;
    let crop_height = cropping.crop_height;

    let pixel_coords = vec2<f32>(
        input.texture_coords.x * video_width, 
        input.texture_coords.y * video_height
    );

    let colour = textureSample(texture, sampler_, input.texture_coords);

    if ((pixel_coords.x > top_left_corner_crop.x && pixel_coords.x < top_left_corner_crop.x + crop_width) || 
        (pixel_coords.y > top_left_corner_crop.y && pixel_coords.y < top_left_corner_crop.y + crop_height)) {
        
        return vec4<0.0, 0.0, 0.0, 0.0>
    } else {
        return colour;
    }
}
