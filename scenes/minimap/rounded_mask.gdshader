shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 50.0) = 8.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float border_width : hint_range(0.0, 10.0) = 2.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Signed distance function for rounded rectangle
float rounded_rect_sdf(vec2 p, vec2 size, float radius) {
    vec2 d = abs(p) - size + radius;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - radius;
}

void fragment() {
    vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
    vec2 half_size = size * 0.5;
    vec2 p = UV * size - half_size;

    float dist = rounded_rect_sdf(p, half_size, corner_radius);

    // Main content with anti-aliased rounded corners
    float alpha = 1.0 - smoothstep(-1.0, 1.0, dist);

    // Border
    float border_alpha = 1.0 - smoothstep(border_width - 1.0, border_width + 1.0, abs(dist));

    vec4 tex_color = texture(TEXTURE, UV);

    // Combine: content inside, border on edge
    vec4 final_color = tex_color;
    final_color.a *= alpha;

    // Add border
    final_color = mix(final_color, border_color, border_alpha * border_color.a);
    final_color.a = max(final_color.a, border_alpha * border_color.a);

    // Apply opacity
    final_color.a *= opacity;

    COLOR = final_color;
}
