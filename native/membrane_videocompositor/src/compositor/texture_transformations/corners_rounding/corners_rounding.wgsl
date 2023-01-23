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

struct CornersRoundingUnifrom{
    border_radius: f32,
    video_width: f32,
    video_height: f32
}

@group(0) @binding(0)
var texture: texture_2d<f32>;

@group(1) @binding(0)
var sampler_: sampler;

@group(2) @binding(0)
var<uniform> corners_rounding_uniform: CornersRoundingUnifrom;

struct IsInCorner {
    left_border: f32,
    right_border: f32,
    top_border: f32,
    bot_border: f32,
}

fn get_nearest_inner_corner_coords_in_pixels(
    is_on_edge: IsInCorner,
    video_width: f32,
    video_height: f32,
    border_radius: f32
) -> vec2<f32> {
    let x = is_on_edge.left_border * border_radius + is_on_edge.right_border * (video_width - border_radius);
    let y = is_on_edge.top_border * border_radius + is_on_edge.bot_border * (video_height - border_radius);

    return vec2(x, y);
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // Firstly calculates, whether the pixel is in the square in one of the video corners,
    // then calculates the distance to the center of the circle located in corner of the video
    // and applies the smoothstep functon to the alpha value of the pixel.

    let border_radius = corners_rounding_uniform.border_radius;
    let video_width = corners_rounding_uniform.video_width;
    let video_height = corners_rounding_uniform.video_height;

    var is_on_edge: IsInCorner;

    is_on_edge.left_border = f32((input.texture_coords.x * video_width) < border_radius);
    is_on_edge.right_border = f32((input.texture_coords.x * video_width) > video_width - border_radius);
    is_on_edge.top_border = f32((input.texture_coords.y * video_height) < border_radius);
    is_on_edge.bot_border = f32((input.texture_coords.y * video_height) > video_height - border_radius);

    let is_in_corner = max(is_on_edge.left_border, is_on_edge.right_border) * max(is_on_edge.top_border, is_on_edge.bot_border);
    let colour = textureSample(texture, sampler_, input.texture_coords);

    let corner_coords = get_nearest_inner_corner_coords_in_pixels(
        is_on_edge,
        video_width,
        video_height,
        border_radius
    );

    let d = distance(input.texture_coords * vec2(video_width, video_height), corner_coords);

    let anti_aliasing_pixels = 1.5;

    let alpha = smoothstep(border_radius + anti_aliasing_pixels, border_radius - anti_aliasing_pixels, d);

    return vec4(colour.xyz, is_in_corner * alpha + (1. - is_in_corner));
}
