#version 430 core

// input vertex attributes
layout (location = 0) in vec2 vPosition;
layout (location = 1) in vec3 particlePosition;

// projection and view matrix
layout (binding = 0, std140) uniform TransformationBlock {
	mat4 viewmat;
	mat4 projmat;
};

out vec2 fTexcoord;
out vec3 fPosition;
flat out uint id;

void main (void)
{

	// pass data to the fragment shader
	vec4 pos = viewmat * vec4 (0.2 * particlePosition.xyz + 0.2 * vec3 (-64, 1, -64), 1.0)  + vec4 (vPosition, 0, 1) * 0.1;
	fTexcoord = vPosition;
	fPosition = pos.xyz;
	id = gl_InstanceID;
	// compute and output the vertex position
	// after view transformation and projection
	gl_Position = projmat * pos;
}
