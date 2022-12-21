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

struct EdgeRounderUnifrom{
    video_width: f32,
    video_height: f32,
    edge_rounding_radius: f32,
}

@group(0) @binding(0)
var texture: texture_2d<f32>;

@group(1) @binding(0)
var sampler_: sampler;

@group(2) @binding(0)
var<uniform> edge_rounder_uniform: EdgeRounderUnifrom;

struct IsInCorner {
    left_border: bool,
    right_border: bool,
    top_border: bool,
    bot_border: bool,
}

fn get_nearest_inner_corner_coords(
    is_on_edge: IsInCorner,
    video_width: f32,
    video_height: f32,
    edge_rounding_radius: f32
) -> vec2<f32> {
    if (is_on_edge.left_border && is_on_edge.top_border) {
        return vec2<f32>(edge_rounding_radius, edge_rounding_radius);
    } else if (is_on_edge.right_border && is_on_edge.top_border) {
        return vec2<f32>(video_width - edge_rounding_radius, edge_rounding_radius);
    } else if (is_on_edge.right_border && is_on_edge.bot_border) {
        return vec2<f32>(video_width - edge_rounding_radius, video_height - edge_rounding_radius);
    } else {
        return vec2<f32>(edge_rounding_radius, video_height - edge_rounding_radius);
    }
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    let video_width = edge_rounder_uniform.video_width;
    let video_height = edge_rounder_uniform.video_height;
    let edge_rounding_radius = edge_rounder_uniform.edge_rounding_radius;

    let tex_coords_in_pixels = vec2<f32>(
        input.texture_coords.x * video_width, 
        input.texture_coords.y * video_height
    );

    var is_on_edge: IsInCorner;

    is_on_edge.left_border = (tex_coords_in_pixels.x < edge_rounding_radius);
    is_on_edge.right_border = (tex_coords_in_pixels.x > video_width - edge_rounding_radius);
    is_on_edge.top_border = (tex_coords_in_pixels.y < edge_rounding_radius);
    is_on_edge.bot_border = (tex_coords_in_pixels.y > video_height - edge_rounding_radius);

    let is_in_corner = ( (is_on_edge.left_border || is_on_edge.right_border) && (is_on_edge.top_border || is_on_edge.bot_border) );
    let colour = textureSample(texture, sampler_, input.texture_coords);

    if (is_in_corner) {
        let corner_coords_in_pixel = get_nearest_inner_corner_coords(
            is_on_edge,
            video_width, 
            video_height, 
            edge_rounding_radius
        );

        if (sqrt(
                    pow(tex_coords_in_pixels.x - corner_coords_in_pixel.x, 2.0) + 
                    pow(tex_coords_in_pixels.y - corner_coords_in_pixel.y, 2.0)
            ) > edge_rounding_radius) {
            return vec4<f32>(0.0, 0.0, 0.0, 0.0);
        }
        return colour;
    } else {
        return colour;
    }
}
