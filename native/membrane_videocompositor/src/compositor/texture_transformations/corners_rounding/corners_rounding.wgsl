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
    left_border: bool,
    right_border: bool,
    top_border: bool,
    bot_border: bool,
}

fn get_nearest_inner_corner_coords_in_pixels(
    is_on_edge: IsInCorner,
    video_width: f32,
    video_height: f32,
    border_radius: f32
) -> vec2<f32> {
    if (is_on_edge.left_border && is_on_edge.top_border) {
        return vec2<f32>(border_radius, border_radius);
    } else if (is_on_edge.right_border && is_on_edge.top_border) {
        return vec2<f32>(video_width - border_radius, border_radius);
    } else if (is_on_edge.right_border && is_on_edge.bot_border) {
        return vec2<f32>(video_width - border_radius, video_height - border_radius);
    } else {
        return vec2<f32>(border_radius, video_height - border_radius);
    }
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // Firstly calculates, whether the pixel is in the square in one of the video corners,
    // then calculates the distance to the center of the circle located in corner of the video
    // and if the distance is larger than the circle radius, it makes the pixel transparent.

    let border_radius = corners_rounding_uniform.border_radius;
    let video_width = corners_rounding_uniform.video_width;
    let video_height = corners_rounding_uniform.video_height;

    var is_on_edge: IsInCorner;

    is_on_edge.left_border = (input.texture_coords.x * video_width < border_radius);
    is_on_edge.right_border = (input.texture_coords.x * video_width > video_width - border_radius);
    is_on_edge.top_border = (input.texture_coords.y * video_height < border_radius);
    is_on_edge.bot_border = (input.texture_coords.y * video_height > video_height - border_radius);

    let is_in_corner = ( (is_on_edge.left_border || is_on_edge.right_border) && (is_on_edge.top_border || is_on_edge.bot_border) );
    let colour = textureSample(texture, sampler_, input.texture_coords);

    if (is_in_corner) {
        let corner_coords = get_nearest_inner_corner_coords_in_pixels(
            is_on_edge,
            video_width,
            video_height,
            border_radius
        );

        // to avoid non efficient sqrt function
        // sqrt(a^2+b^2) > c <=> a^2+b^2 > c^2
        if (pow(input.texture_coords.x * video_width - corner_coords.x, 2.0) + 
            pow(input.texture_coords.y * video_height - corner_coords.y, 2.0)
            > pow(border_radius, 2.0)) {
            return vec4<f32>(0.0, 0.0, 0.0, 0.0);
        }
    }
    return colour;
}
