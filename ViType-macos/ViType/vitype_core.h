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
void vitype_engine_set_output_encoding(VitypeEngine *engine, int32_t encoding);
VitypeTransformResult vitype_engine_process(VitypeEngine *engine, const char *input_utf8);
void vitype_engine_free_string(char *text);

#ifdef __cplusplus
}
#endif

#endif
