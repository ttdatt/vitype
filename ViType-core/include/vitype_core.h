#ifndef VITYPE_CORE_H
#define VITYPE_CORE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct VitypeEngine VitypeEngine;

typedef struct {
    bool has_action;
    int32_t delete_count;
    char *text;
} VitypeTransformResult;

VitypeEngine *vitype_engine_new(void);
void vitype_engine_free(VitypeEngine *engine);
void vitype_engine_reset(VitypeEngine *engine);
void vitype_engine_delete_last_character(VitypeEngine *engine);
void vitype_engine_set_auto_fix_tone(VitypeEngine *engine, bool enabled);
void vitype_engine_set_free_tone_placement(VitypeEngine *engine, bool enabled);
void vitype_engine_set_input_method(VitypeEngine *engine, int32_t method);  // 0 = Telex, 1 = VNI
void vitype_engine_set_output_encoding(VitypeEngine *engine, int32_t encoding);
void vitype_engine_set_tone_placement(VitypeEngine *engine, int32_t placement); // 0 = Orthographic, 1 = NucleusOnly
VitypeTransformResult vitype_engine_process(VitypeEngine *engine, const char *input_utf8);
int32_t vitype_engine_get_buffer_len(VitypeEngine *engine);
char *vitype_engine_get_composed_text(VitypeEngine *engine);
void vitype_engine_free_string(char *text);

#ifdef __cplusplus
}
#endif

#endif
