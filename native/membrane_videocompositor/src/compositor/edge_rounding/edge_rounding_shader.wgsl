// TO TEST
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

struct VideoResolution {
    @location(0) width: f32,
    @location(1) height: f32
}

@group(0) @binding(0)
var texture: texture_2d<f32>;

@group(1) @binding(0)
var sampler_: sampler;

@group(2) @binding(0)
var<uniform> video_resolution: VideoResolution;

@group(3) @binding(0)
var<uniform> edge_rounding_radius: f32;

fn get_nearest_inner_corner_coords(left_border: bool, right_border: bool, top_border: bool, bot_border: bool) -> vec2<f32> {
    if (left_border && top_border) {
        return vec2<f32>(edge_rounding_radius, edge_rounding_radius);
    } else if (right_border && top_border) {
        return vec2<f32>(video_resolution.width - edge_rounding_radius, edge_rounding_radius);
    } else if (right_border && bot_border) {
        return vec2<f32>(video_resolution.width - edge_rounding_radius, video_resolution.height - edge_rounding_radius);
    } else {
        return vec2<f32>(edge_rounding_radius, video_resolution.height - edge_rounding_radius);
    }
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    let tex_coords_in_pixels = vec2<f32>(input.texture_coords.x * video_resolution.width, 
        input.texture_coords.y * video_resolution.height);

    let left_border = (tex_coords_in_pixels.x < edge_rounding_radius);
    let right_border = (tex_coords_in_pixels.x > video_resolution.width - edge_rounding_radius);
    let top_border = (tex_coords_in_pixels.y < edge_rounding_radius);
    let bot_border = (tex_coords_in_pixels.y > video_resolution.height - edge_rounding_radius);

    let is_in_corner_box = ( (left_border || right_border) && (top_border || bot_border) );
    let colour = textureSample(texture, sampler_, input.texture_coords);

    if (is_in_corner_box) {
        let corner_coords_in_pixel = get_nearest_inner_corner_coords(left_border, right_border, top_border, bot_border);

        if (sqrt(
                    pow(tex_coords_in_pixels.x - corner_coords_in_pixel.x, 2.0) + 
                    pow(tex_coords_in_pixels.y - corner_coords_in_pixel.y, 2.0)
            ) < edge_rounding_radius) {
            return vec4<f32>(colour.x, colour.y, colour.z, 1.0);
        }
        return colour;
    } else {
        return colour;
    }

}
