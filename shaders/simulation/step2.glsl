// include.glsl is included here
#line 3

layout (local_size_x = 256) in;

struct ParticleInfo
{
	vec3 position;
	vec3 oldposition;
};

layout (std430, binding = 0) readonly buffer ParticleBuffer
{
	ParticleInfo particles[];
};

layout (std430, binding = 3) writeonly buffer GridBuffer
{
	int grid[];
};

layout (std430, binding = 4) writeonly buffer FlagBuffer
{
	int flag[];
};

uint GetHash (in vec3 pos)
{
	ivec3 grid;
	grid.x = clamp (int (floor (pos.x)), 0, GRID_WIDTH);
	grid.y = clamp (int (floor (pos.y)), 0, GRID_HEIGHT);
	grid.z = clamp (int (floor (pos.z)), 0, GRID_DEPTH);
	
	return grid.y * GRID_WIDTH * GRID_DEPTH + grid.z * GRID_WIDTH + grid.x;
}

void main (void)
{
	uint gid;
	gid = gl_GlobalInvocationID.x;
	
	if (gid == 0)
	{
		grid[0] = 0;
		flag[0] = 0;
		flag[NUM_PARTICLES] = 1;
		return;
	}

	uint hash = GetHash (particles[gid].position);
	
	if (hash != GetHash (particles[gid - 1].position))
	{
		grid[hash] = int (gid);
		flag[gid] = 1;
	}
	else
	{
		flag[gid] = 0;
	}
}
