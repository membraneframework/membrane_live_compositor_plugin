struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) texture_coords: vec2<f32>
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texture_coords: vec2<f32>,
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

fn get_scale_matrix(x_scale_factor: f32, y_scale_factor: f32) -> mat3x3<f32> {
    return mat3x3<f32>(
        x_scale_factor, 0.0, 0.0,  // col 1
        0.0, y_scale_factor, 0.0,  // col 2
        0.0, 0.0, 1.0  // col 3
    );
}

fn get_translation_matrix(x_translation: f32, y_translation: f32) -> mat3x3<f32> {
    return mat3x3<f32>(
        1.0, 0.0, 0.0,  // col 1
        0.0, 1.0, 0.0,  // col 2
        x_translation, y_translation, 1.0  // col 3
    );
}

fn get_cropped_coords(texture_coords: vec2<f32>, top_left_corner_crop: vec2<f32>, crop_size: vec2<f32>) -> vec2<f32> {
    let scale_matrix = get_scale_matrix(crop_size.x, crop_size.y);
    let translation_matrix = get_translation_matrix(top_left_corner_crop.x, top_left_corner_crop.y);
    return (translation_matrix * scale_matrix * vec3<f32>(texture_coords, 1.0)).xy;
}


@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    output.position = vec4<f32>(input.position, 1.0);
    output.texture_coords = 
        get_cropped_coords(
            input.texture_coords,
            vec2<f32>(cropping.top_left_corner_crop_x, cropping.top_left_corner_crop_y),
            vec2<f32>(cropping.crop_width, cropping.crop_height)
        );

    return output;
}



@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    return textureSample(texture, sampler_, input.texture_coords);
}
