// include.glsl is included here
#line 3

layout (local_size_x = 256) in;

struct ParticleInfo
{
	vec3 position;
	bool highlighted;
	vec3 velocity;
	float density;
	vec3 color;
	float vorticity;	
};

struct ParticleKey
{
	vec3 position;
	uint id;
};

layout (std430, binding = 0) buffer ParticleKeys
{
	ParticleKey particlekeys[];
};

layout (std430, binding = 1) readonly buffer ParticleBuffer
{
	ParticleInfo particles[];
};

layout (std430, binding = 2) buffer LambdaBuffer
{
	float lambdas[];
};

layout (binding = 0) uniform isamplerBuffer neighbourcelltexture;

float Wpoly6 (float r)
{
	if (r > h)
		return 0;
	float tmp = h * h - r * r;
	return 1.56668147106 * tmp * tmp * tmp / (h*h*h*h*h*h*h*h*h);
}

float Wspiky (float r)
{
	if (r > h)
		return 0;
	float tmp = h - r;
	return 4.774648292756860 * tmp * tmp * tmp / (h*h*h*h*h*h);
}

vec3 gradWspiky (vec3 r)
{
	float l = length (r);
	if (l > h || l == 0)
		return vec3 (0, 0, 0);
	float tmp = h - l;
	return (-3 * 4.774648292756860 * tmp * tmp) * r / (l * h*h*h*h*h*h);
}

#define FOR_EACH_NEIGHBOUR(var) for (int o = 0; o < 3; o++) {\
		ivec3 datav = texelFetch (neighbourcelltexture, int (gl_GlobalInvocationID.x * 3 + o)).xyz;\
		for (int comp = 0; comp < 3; comp++) {\
		int data = datav[comp];\
		int entries = data >> 24;\
		data = data & 0xFFFFFF;\
		if (data == 0) continue;\
		for (int var = data; var < data + entries; var++) {\
		if (var != gl_GlobalInvocationID.x) {
#define END_FOR_EACH_NEIGHBOUR(var)	}}}}

void main (void)
{
	vec3 position = particlekeys[gl_GlobalInvocationID.x].position;

	float sum_k_grad_Ci = 0;
	float rho = 0;

	vec3 grad_pi_Ci = vec3 (0, 0, 0);
	
	FOR_EACH_NEIGHBOUR(j)
	{
		vec3 position_j = particlekeys[j].position;
		
		// compute rho_i (equation 2)
		float len = distance (position, position_j);
		float tmp = Wpoly6 (len);
		rho += tmp;
	
		// sum gradients of Ci (equation 8 and parts of equation 9)
		// use j as k so that we can stay in the same loop
		vec3 grad_pk_Ci = vec3 (0, 0, 0);
		grad_pk_Ci = gradWspiky (position - position_j);
		grad_pk_Ci /= rho_0;
		sum_k_grad_Ci += dot (grad_pk_Ci, grad_pk_Ci);
		
		// now use j as j again and accumulate grad_pi_Ci for the case k=i
		// from equation 8
		grad_pi_Ci += grad_pk_Ci; // = gradWspiky (particle.position - particles[j].position); 
	}
	END_FOR_EACH_NEIGHBOUR(j)
	// add grad_pi_Ci to the sum
	sum_k_grad_Ci += dot (grad_pi_Ci, grad_pi_Ci);
	
	// compute lambda_i (equations 1 and 9)
	float C_i = rho / rho_0 - 1;
	float lambda = -C_i / (sum_k_grad_Ci + epsilon);
	lambdas[gl_GlobalInvocationID.x] = lambda;
	
	barrier ();
	memoryBarrierBuffer ();
	
	vec3 deltap = vec3 (0, 0, 0);
			
	FOR_EACH_NEIGHBOUR(j)
	{
		vec3 position_j = particlekeys[j].position;
		
		float scorr = (Wpoly6 (distance (position, position_j)) / Wpoly6 (tensile_instability_h));
		scorr *= scorr;
		scorr *= scorr;
		scorr = -tensile_instability_k * scorr;  
	
		// accumulate position corrections (part of equation 12)
		deltap += (lambda + lambdas[j] + scorr) * gradWspiky (position - position_j);
	}
	END_FOR_EACH_NEIGHBOUR(j)

	position += deltap / rho_0;

	// collision detection begin
	vec3 wall = vec3 (16, 0, 16);
	position = clamp (position, vec3 (0, 0, 0) + wall, GRID_SIZE - wall);
	// collision detection end
	
	particlekeys[gl_GlobalInvocationID.x].position = position;
}
