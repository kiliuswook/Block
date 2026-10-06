// CanvasGroup 용 셰이더: 로고 전체를 한 장으로 합성한 뒤
// (1) 임팩트 순간의 과노출 틴트, (2) 대각선 빛줄기를 더한다.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float progress = -1.0;          // 빛줄기 위치 (화면 UV.x 기준)
uniform float band_width = 0.07;
uniform vec4 shine_color : source_color = vec4(1.0, 0.82, 0.4, 0.9);
uniform vec4 tint_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float tint_amount = 0.0;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	c.rgb = mix(c.rgb, tint_color.rgb, tint_amount);
	float d = (SCREEN_UV.x - progress) + (SCREEN_UV.y - 0.5) * 0.45;
	float band = 1.0 - smoothstep(0.0, band_width, abs(d));
	c.rgb = mix(c.rgb, shine_color.rgb, band * shine_color.a);
	COLOR *= c;
}
