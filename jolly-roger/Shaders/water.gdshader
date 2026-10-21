shader_type canvas_item;
// Animated pixel-art water for the Water node's Body (a ColorRect).
// Colours default to the Treasure Hunters "Additional Water" palette.

uniform vec2 rect_size = vec2(96.0, 112.0);
uniform vec4 water_color : source_color = vec4(0.573, 0.663, 0.808, 0.75);
uniform vec4 deep_color : source_color = vec4(0.333, 0.420, 0.659, 0.9);
uniform vec4 foam_color : source_color = vec4(0.867, 0.925, 1.0, 1.0);
uniform vec4 streak_color : source_color = vec4(0.729, 0.808, 0.925, 0.85);
uniform float wave_height = 2.0;     // pixels
uniform float wave_length = 28.0;    // pixels
uniform float wave_speed = 2.5;
uniform float foam_thickness = 2.0;  // pixels
uniform float depth_fade = 80.0;     // pixels until fully deep_color

void fragment() {
	vec2 p = floor(UV * rect_size);   // whole pixels keeps it crisp

	float a = p.x / wave_length * 6.2832 + TIME * wave_speed;
	float b = p.x / (wave_length * 0.43) * 6.2832 - TIME * wave_speed * 1.6;
	float surface = floor(wave_height * (0.5 + 0.5 * sin(a)) + 0.5 + 0.5 * sin(b));

	if (p.y < surface) {
		COLOR = vec4(0.0);
	} else if (p.y < surface + foam_thickness) {
		COLOR = foam_color;
	} else {
		float t = clamp((p.y - surface) / depth_fade, 0.0, 1.0);
		vec4 c = mix(water_color, deep_color, t);
		// Drifting light streaks under the surface.
		float row = p.y - surface;
		float drift = floor(p.x + TIME * 10.0 + sin(p.y * 0.7) * 6.0);
		if (mod(row, 14.0) == 6.0 && mod(drift, 40.0) < 10.0) {
			c = mix(c, streak_color, 1.0 - t);
		}
		COLOR = c;
	}
}
