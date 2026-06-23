shader_type canvas_item;

// Reads a single-channel reveal mask (R = revealed amount) and turns it into an
// opaque dark overlay over hidden tiles, fully transparent over revealed ones.

uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float revealed = texture(TEXTURE, UV).r;
	COLOR = vec4(fog_color.rgb, fog_color.a * (1.0 - revealed));
}
