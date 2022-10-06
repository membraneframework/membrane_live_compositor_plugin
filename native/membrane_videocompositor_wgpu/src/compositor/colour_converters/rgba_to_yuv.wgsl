struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) tex_coords: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) tex_coords: vec2<f32>,
}

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    output.position = vec4(input.position, 1.0);
    output.tex_coords = input.tex_coords;

    return output;
}

@group(0) @binding(0) var texture: texture_2d<f32>;
@group(1) @binding(0) var sampler_: sampler;
@group(2) @binding(0) var<uniform> plane_selector: u32;

fn uv_pixel_iter(tex_coords: vec2<f32>, conversion: vec4<f32>) -> f32 {
    let dimensions = textureDimensions(texture);
    let offset = vec2<f32>(0.5 / f32(dimensions.x), 0.5 / f32(dimensions.y));

    var result: f32 = 0.0;

    for(var i: i32 = -1; i <= 1; i++) {
        if(i == 0) { continue; }
        for(var j: i32 = -1; j < 1; j++) {
            if(j == 0) { continue; }

            let offset2 = vec2<f32>(f32(i) * offset.x, f32(j) * offset.y);

            result += dot(textureSample(texture, sampler_, tex_coords + offset2), conversion) + 0.5;
        }
        
    }

    return result / 4.0;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) f32 {
    let colour = textureSample(texture, sampler_, input.tex_coords);
    var conversion_weights: vec4<f32>;
    var conversion_bias: f32;

    if(plane_selector == 0u) {
        // Y
        conversion_weights = vec4<f32>(0.299, 0.587, 0.114, 0.0);
        conversion_bias = 0.0;
    } else if(plane_selector == 1u) {
        // U
        conversion_weights = vec4<f32>(-0.168736, -0.331264, 0.5, 0.0);
        conversion_bias = 0.5;
    } else if(plane_selector == 2u) {
        // V
        conversion_weights = vec4<f32>(0.5, -0.418688, -0.081312, 0.0);
        conversion_bias = 0.5;
    } else {
        conversion_weights = vec4<f32>();
    }

    return clamp(dot(colour, conversion_weights) + conversion_bias, 0.0, 1.0);
}
