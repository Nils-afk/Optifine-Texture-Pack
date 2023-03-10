#version 150

#moj_import <light.glsl>
#moj_import <fog.glsl>
#moj_import <crystal_util.glsl>

#define PI 3.1415926535897932

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in vec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat4 IdentityMat;
uniform mat3 IViewRotMat;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;
uniform float GameTime;
uniform int FogShape;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out float check_discard;

void main() {

	vec4 col = texture(Sampler0, UV0);
	
	float check_hand = float(abs(Normal) == vec3(0.0)); // is the crystal in the player's hand in firstperson?
	float check_inventory = float(ProjMat[0][0] < 1.5/255.0 && ProjMat[1][1] < 0.5/255.0 && ProjMat[2][2] < 0.5/255.0); // is the crystal in a GUI?
	float check_inventory_hand = float(Light0_Direction.r > Light0_Direction.g && Light0_Direction.r > Light0_Direction.b && check_hand == 0.0); // is this crystal in the player's hand in the GUI?
	float check_show_billboard = check_inventory * (1.0 - check_inventory_hand);
	
	vec2 d = col.ra - vec2(255.0, 63.0) / 255.0;
	float check_crystal = float(dot(d, d) < EPSILON); // is the thing a crystal?
	float e = col.g - 63.0/255.0;
	float check_middle_layer = float(e*e < EPSILON); // middle layer of the crystal?
	e = col.g - 127.0/255.0;
	float check_inner_layer = float(e*e < EPSILON); // inner layer of the crystal?
	e = col.g - 191.0/255.0;
	float check_billboard_texture = float(e*e < EPSILON); // inventory tex?
	
	check_discard = check_crystal * min(1.0, check_show_billboard * (1.0 - check_billboard_texture) + (1.0 - check_show_billboard) * check_billboard_texture);
	
	mat4 wm = mat4(inverse(IViewRotMat)) * (1.0 - min(1.0, check_inventory + check_hand)) // use world matrix unless...
	        + IdentityMat * min(1.0, check_inventory + check_hand); // if in inventory or firstperson hand, then use identity matrix
	
	float rt = GameTime * 1000.0; // rotation value

	float model_scale = 0.125 // base scale
					  + 0.125 * sign(check_inventory + check_hand) // larger if in inventory or firstperson hand
					  + 0.25 * check_inventory // even larger if in inventory
					  + 3.5 * check_inventory * check_inventory_hand; // even larger if in inventory and held by the character model	

	mat4 standard_rotation = rotate(vec3(wm[1].xyz), rt) * rotate(vec3(wm[2].xyz), 35.0*PI/180.0) * rotate(vec3(wm[0].xyz), PI/4.0);
	mat4 rotation = (standard_rotation * check_inner_layer + IdentityMat * (1.0 - check_inner_layer)) // inner layer
				  * (standard_rotation * min(1.0, check_middle_layer + check_inner_layer) + IdentityMat * (1.0 - min(1.0, check_middle_layer + check_inner_layer))) // middle layer
				  * standard_rotation; // standard crystal rotation
	model_scale *= (1.0 - 0.125 * min(1.0, check_middle_layer + check_inner_layer)) * (1.0 - 0.125 * check_inner_layer);
	
	vec4 a = translate(Position) * rotation * wm * vec4(-model_scale*(get_offset(col)), 1.0) * check_crystal * (1.0 - check_show_billboard) // crystal
		   + translate(Position) * vec4(-model_scale*(get_offset(col)), 1.0) * check_crystal * check_show_billboard // not crystal, or crystal in inventory
		   + vec4(Position, 1.0) * (1.0 - check_crystal); // not crystal, or crystal in inventory
	vertexColor = texelFetch(Sampler2, UV2 / 16, 0) // light level
				* (minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color) * (1.0 - check_crystal) + vec4(1.0) * check_crystal); // shade only if not crystal
	
    gl_Position = ProjMat * ModelViewMat * a;

    vertexDistance = fog_distance(ModelViewMat, IViewRotMat * Position, FogShape);
    texCoord0 = UV0;
}
