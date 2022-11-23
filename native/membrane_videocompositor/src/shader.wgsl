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

// @group(0) @binding(0)
// var texture: texture_2d<f32>;
// 
// @group(1) @binding(0)
// var sampler_: sampler;
// 
// @fragment
// fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
//     return textureSample(texture, sampler_, input.texture_coords);
// }

@group(0) @binding(0)
var texture: texture_2d<f32>;

@group(1) @binding(0)
var sampler_: sampler;


fn get_nearest_inner_corner_coords(left_border: bool, right_border: bool, top_border: bool, bot_border: bool) -> vec2<f32> {
    let video_resolution_width = 1280.0;
    let video_resolution_height = 720.0;
    let edge_rounding_radius = 75.0;

    if left_border && top_border {
        return vec2<f32>(edge_rounding_radius, edge_rounding_radius);
    } else if right_border && top_border {
        return vec2<f32>(video_resolution_width - edge_rounding_radius, edge_rounding_radius);
    } else if right_border && bot_border {
        return vec2<f32>(video_resolution_width - edge_rounding_radius, video_resolution_height - edge_rounding_radius);
    } else {
        return vec2<f32>(edge_rounding_radius, video_resolution_height - edge_rounding_radius);
    }
}

fn change_alpha(colour: vec4<f32>, distance_from_center: f32, radius: f32) -> vec4<f32> {
    let antialiasing_coeficient = 0.1;
    if distance_from_center > radius * antialiasing_coeficient {
        return vec4<f32>(colour.xyz, 0.0);
    } else if distance_from_center < radius * antialiasing_coeficient {
        return colour;
    } else {
        return vec4<f32>(colour.xyz, 0.5 + ((distance_from_center - radius) / (2.0 * antialiasing_coeficient * radius)));
    }
}

fn hypot(a: f32, b: f32) -> f32 {
    return sqrt(pow(a, 2.0) + pow(b, 2.0));
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    let video_resolution_width = 1280.0;
    let video_resolution_height = 720.0;
    let edge_rounding_radius = 75.0;

    let tex_coords_in_pixels = vec2<f32>(input.texture_coords.x * video_resolution_width, input.texture_coords.y * video_resolution_height);

    let left_border = (tex_coords_in_pixels.x < edge_rounding_radius);
    let right_border = (tex_coords_in_pixels.x > video_resolution_width - edge_rounding_radius);
    let top_border = (tex_coords_in_pixels.y < edge_rounding_radius);
    let bot_border = (tex_coords_in_pixels.y > video_resolution_height - edge_rounding_radius);

    let is_in_corner_box = ((left_border || right_border) && (top_border || bot_border));
    let colour = textureSample(texture, sampler_, input.texture_coords);

    if is_in_corner_box {
        let corner_coords_in_pixel = get_nearest_inner_corner_coords(left_border, right_border, top_border, bot_border);
        let distance_from_center = hypot(
            tex_coords_in_pixels.x - corner_coords_in_pixel.x,
            tex_coords_in_pixels.y - corner_coords_in_pixel.y
        );
        // return change_alpha(colour, distance_from_center, edge_rounding_radius);
        if distance_from_center > edge_rounding_radius {
            return vec4<f32>(1.0, 0.0, 0.0, 0.0);
        }
        return vec4<f32>(colour.xyz, 1.0);
    } else {
        return vec4<f32>(colour.xyz, 1.0);
    }
}
