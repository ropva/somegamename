shader_type canvas_item;

uniform float cell_size = 40.0;
uniform vec2 speed = vec2(0.2, 0.2);
uniform float angle_degrees : hint_range(-180.0, 180.0) = 0.0; // Угол наклона в градусах

uniform bool enable_lines = false; 
uniform float line_thickness : hint_range(0.0, 0.5) = 0.02;
uniform vec4 grid_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 alternate_color : source_color = vec4(0.15, 0.15, 0.15, 1.0);

// Функция для поворота 2D вектора вокруг центра (0,0)
vec2 rotate(vec2 uv, float angle_rad) {
	float s = sin(angle_rad);
	float c = cos(angle_rad);
	return vec2(
		uv.x * c - uv.y * s,
		uv.x * s + uv.y * c
	);
}

void fragment() {
	// Сначала переводим координаты в масштаб ячеек
	vec2 custom_uv = FRAGCOORD.xy / cell_size;
	
	// Вращаем координаты (переводим градусы в радианы: deg * PI / 180.0)
	float angle_rad = angle_degrees * 3.14159265359 / 180.0;
	custom_uv = rotate(custom_uv, angle_rad);
	
	// Движение применяем уже ПОСЛЕ поворота (или до, если хочешь, чтобы направление движения тоже поворачивалось)
	custom_uv -= speed * TIME;
	
	vec2 grid_uv = fract(custom_uv);
	
	// 1. ОПРЕДЕЛЯЕМ ЦВЕТ КЛЕТКИ (ШАХМАТКА)
	vec2 cell_index = floor(custom_uv);
	float checker = mod(cell_index.x + cell_index.y, 2.0);
	vec4 current_cell_color = mix(background_color, alternate_color, checker);
	
	if (!enable_lines) {
		COLOR = current_cell_color;
	} else {
		// 2. СГЛАЖИВАНИЕ ЛИНИЙ СЕТКИ (fwidth)
		vec2 derivative = fwidth(custom_uv);
		vec2 target_dist = vec2(line_thickness);
		vec2 blend_v = smoothstep(target_dist, target_dist + derivative, grid_uv) * 
					   smoothstep(target_dist, target_dist + derivative, 1.0 - grid_uv);
		
		float grid_mask = blend_v.x * blend_v.y;
		
		// 3. ФИЛЬТРАЦИЯ И ЗАЩИТА ОТ МЕРЦАНИЯ (LOD FADE)
		float lod_fade = smoothstep(0.5, 0.1, max(derivative.x, derivative.y));
		
		vec4 average_color = mix(background_color, alternate_color, 0.5); 
		vec4 final_grid_color = mix(average_color, grid_color, lod_fade);
		
		// 4. ФИНАЛЬНЫЙ ВЫВОД
		COLOR = mix(final_grid_color, current_cell_color, grid_mask);
	}
}
