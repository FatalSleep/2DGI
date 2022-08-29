
/*
    GI STAGES: (surfaces)
    1. [INITIAL] Initial Scene Render
    2. [PREJUMP] Pre-Jump Flood
    3. [JUMPFLD] Jump flood
        3a. [JMPFLDA] Jump flood pass A
        3b. [JMPFLDB] Jump flood pass B
    4. [DISTFLD] DF from Jump Flood
    5. [GOLDNSE] Random noise texture
    6. [GILIGHT] Scene Random Temporal Raymarch
    7. [POSTPRC] Post-Process Bloom
    8. [DENOISE] Denoise Post-Process GI scene.
    
    How this works:
        1. Take an input scene [STAGE 1] as a surface and then feed the input scene into the current temporal GI surface.
        2. Prepare input scene for jumpflooding [STAGE 2].
        3. Generate a jumpflood texture [STAGE 2] from the input scene.
            3ab. Jumpflood iterates overitself, requiring two passes/surfaces.
        4. Generate a distance field [STAGE 3] of the input scene from the jump flood.
        5. Generate a texture for random noise [STAGE 4].
        6. Pass stages 4 & 5 surfaces to the GI shader along with the current temporal GI surface [STAGE 6].
            6a. Raymarch the scene and get emissive color surfaces.
            6b. If no emissive color is found, check the nearest pixel outside the nearest emissive surface pixel.
            6c. Tonemap the final color for displaying to the surface.
        7. Apply bloom using additive blending [STAGE 7].
*/
game_set_speed(gamespeed_fps, 120);
enum GISTAGES { INITIAL, PREJUMP, JMPFLDA, JMPFLDB, DISTFLD, GOLDNSE, POSTPRC, DENOISE }
enum GISHADER {
    PREJUMP = Shd_PREJUMP, /* Pre-JumpFlood Setup */
    JUMPFLD = Shd_JUMPFLD, /* Jump Flood */
    DISTFLD = Shd_DISTFLD, /* Distance Field */
    GOLDNSE = Shd_GOLDNSE, /* Random noise */
    GILIGHT = Shd_GILIGHT, /* Light bounce */
    DENOISE = Shd_DENOISE  /* Denoiser */
}

gistage_resw = 1920 / 4; // GI resolution
gistage_resh = 1080 / 4; // GI resolution
gistage_rndw = 1920 / 2; // GI upscale resolution
gistage_rndh = 1080 / 2; // GI upscale resolution
gistage_numb =    9; // GI stages count
gistage_iter =    0; // GI temporal iterator
gistage_tmpk =    2; // GI temporal count
gistage_time =    0; // GI time iterator
gistage_dnse =    0; // Number of Denoise Samples
gistage_curr =    0; // Current GI stage.
/*
    The GI stage is cumulative so light bounces accumulate over real-time (see stage 7 draw event).
    However if the GI stage is calculated using a for-loop per frame rather than accumuilating
    over several frames then the temporal count >2 is necessary.
*/


// Grab shader variable uniforms for passing data to shaders.
JUMPFLD_inJdist = shader_get_uniform(GISHADER.JUMPFLD, "in_Jdist");
JUMPFLD_inResol = shader_get_uniform(GISHADER.JUMPFLD, "in_Resol");
GOLDNSE_inTimer = shader_get_uniform(GISHADER.GOLDNSE, "in_Timer");
GOLDNSE_inResol = shader_get_uniform(GISHADER.GOLDNSE, "in_Resol");
GILIGHT_inResol = shader_get_uniform(GISHADER.GILIGHT, "in_Resol");
GILIGHT_inDistfld = shader_get_sampler_index(GISHADER.GILIGHT, "in_Distfld");
GILIGHT_inGoldnse = shader_get_sampler_index(GISHADER.GILIGHT, "in_Goldnse");
DENOISE_inResol = shader_get_uniform(GISHADER.DENOISE, "in_Resol");

// Initialize all GI stage surfaces and GI temporal surfaces.
var i = 0; repeat(gistage_numb) {
    gistage_surf[i] = surface_create(gistage_resw, gistage_resh);
    i++;
}
var i = 0; repeat(gistage_tmpk) {
    gistage_temp[i] = surface_create(gistage_resw, gistage_resh);
    i++;
}