#ifndef UNIVSKY_VOLUMETRIC_CLOUDS
#define UNIVSKY_VOLUMETRIC_CLOUDS

uniform sampler2D volumetric_clouds_blend_from_texture:
	filter_linear, repeat_disable, source_color;
uniform sampler2D volumetric_clouds_blend_to_texture:
	filter_linear, repeat_disable, source_color;
uniform float volumetric_clouds_blend_amount: hint_range(0.0, 1.0) = 0.0;
uniform float volumetric_clouds_intensity = 1.0;

vec2 volumetricCloudsOctWrap(vec2 value){
	vec2 signs = vec2(value.x >= 0.0 ? 1.0 : -1.0, value.y >= 0.0 ? 1.0 : -1.0);
	return (1.0 - abs(value.yx)) * signs;
}

vec2 volumetricCloudsDirectionToOct(vec3 direction){
	direction /= abs(direction.x) + abs(direction.y) + abs(direction.z);
	direction.xy = direction.z >= 0.0
		? direction.xy
		: volumetricCloudsOctWrap(direction.xy);

	vec2 encoded;
	encoded.y = direction.y * 0.5 + 0.5;
	encoded.x = direction.x * 0.5 + encoded.y;
	encoded.y = direction.x * -0.5 + encoded.y;
	return encoded;
}

vec4 sampleVolumetricClouds(vec3 eyeDirection){
	vec3 direction = eyeDirection;
	direction.y = max(0.0, direction.y);
	direction = normalize(direction);
	vec2 uv = volumetricCloudsDirectionToOct(direction.xzy);
	vec4 blendFrom = textureLod(volumetric_clouds_blend_from_texture, uv, 0.0);
	vec4 blendTo = textureLod(volumetric_clouds_blend_to_texture, uv, 0.0);
	vec4 clouds = mix(blendFrom, blendTo, volumetric_clouds_blend_amount);

	// Hide artifacts from long rays near the horizon.
	// sweet spot is around 0.6-0.8.
	// 0.9-1.0 looks weird near the horizon.
	float horizonFade = 1.0 - smoothstep(0.75, 1.0, 1.0 - eyeDirection.y);
	clouds.a *= horizonFade;
	clouds.rgb *= volumetric_clouds_intensity;
	return clouds;
}

#endif
