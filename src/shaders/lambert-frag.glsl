#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

const vec3 positional1 = vec3(100, 0, 0);
const vec3 positional2 = vec3(0, -100, 0);
const vec3 positional3 = vec3(33, 44, -12.4);
const float scale = 43758.5453f;
const int rounds = 6;

float interpQuintic(float x, float a, float b) {
    float mod = 1.f - 6.f * pow(x, 5.f) + 15.f * pow(x, 4.f) - 10.f * pow(x, 3.f); 
    return mod * a + (1.f - mod) * b;
}

vec3 detChaos(vec3 p) {
    float x = fract(sin(dot(p, vec3(-1.1, 20.f, -22.999))) * 43758.5453);
    float y = fract(sin(dot(p, vec3(0.1, 111.7, -91.999))) * 13757.5353);
    float z = fract(sin(dot(p, vec3(126.1, -111.7, 191.999))) * 23758.5453);
   return normalize(vec3(x, y, z));
}

const float pVoxelSize = 0.5f;

float trilinear(vec3 p, float bnl, float bnr, float bfr, float bfl, float tnl, float tnr, float tfr, float tfl) {
   vec3 base = floor(p);
   vec3 diff = p - base;
   float bl = interpQuintic(diff.z, bnl, bfl);
   float br = interpQuintic(diff.z, bnr, bfr);
   float tl = interpQuintic(diff.z, tnl, tfl);
   float tr = interpQuintic(diff.z, tnr, tfr);

   float l = interpQuintic(diff.y, bl, tl);
   float r = interpQuintic(diff.y, br, tr);

   return interpQuintic(diff.x, l, r);
}

float perlin(vec3 p) {
    p.x += 100.f;
    float px = floor(p.x / pVoxelSize);
    float py = floor(p.y / pVoxelSize);
    float pz = floor(p.z / pVoxelSize);
    
    p /= pVoxelSize;
    vec3 bnl = detChaos(vec3(px, py, pz));
    vec3 bnr = detChaos(vec3(px + 1.f, py, pz));
    vec3 bfr = detChaos(vec3(px + 1.f, py, pz + 1.f));
    vec3 bfl = detChaos(vec3(px, py, pz + 1.f));
    vec3 tnl = detChaos(vec3(px, py + 1.f, pz));
    vec3 tnr = detChaos(vec3(px + 1.f, py + 1.f, pz));
    vec3 tfr = detChaos(vec3(px + 1.f, py + 1.f, pz + 1.f));
    vec3 tfl = detChaos(vec3(px, py + 1.f, pz + 1.f));

    float dotBnl = dot(p - vec3(px, py, pz), bnl);
    float dotBnr = dot(p - vec3(px + 1.f, py, pz), bnr);
    float dotBfr = dot(p - vec3(px + 1.f, py, pz + 1.f), bfr);
    float dotBfl = dot(p - vec3(px, py, pz + 1.f), bfl);

    float dotTnl = dot(p - vec3(px, py + 1.f, pz), tnl);
    float dotTnr = dot(p - vec3(px + 1.f, py + 1.f, pz), tnr);
    float dotTfr = dot(p - vec3(px + 1.f, py + 1.f, pz + 1.f), tfr);
    float dotTfl = dot(p - vec3(px, py + 1.f, pz + 1.f), tfl);

    return trilinear(p, dotBnl, dotBnr, dotBfr, dotBfl, dotTnl, dotTnr, dotTfr, dotTfl); 
}

vec4 fbm(vec3 p) {
    float acc = 0.f;
    float amplitude = 1.f;
    float freq = 0.5f;
    for (int round = 0; round < rounds; round++) {
        acc += perlin(p * freq);
        amplitude *= 0.8;
        freq *= 1.2f; 
    }

    vec3 a = u_Color.xyz;
    vec3 b = vec3(0.5, 0.5, 0.1);
    vec3 c = vec3(1.f, 1.f, 2.f);
    vec3 d = vec3(0.f, 0.25, 0.75);

    float diffuse_term = dot(normalize(fs_Nor), normalize(fs_LightVec));

    vec3 col = a + b * cos(2.f * 3.14159 * (c * acc + d));
    return vec4(col.x, col.y, col.z, 1.f);
}


void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = fbm(fs_Pos.xyz);

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        diffuseTerm = clamp(diffuseTerm, 0.f, 1.f);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        out_Col = diffuseColor; //vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}
