use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

use unicode_normalization::UnicodeNormalization;

use crate::common::{InputMethod, OutputEncoding, TonePlacement};
use crate::VitypeEngine;

#[repr(C)]
pub struct VitypeTransformResult {
    pub has_action: bool,
    pub delete_count: i32,
    pub text: *mut c_char,
}

fn empty_result() -> VitypeTransformResult {
    VitypeTransformResult {
        has_action: false,
        delete_count: 0,
        text: ptr::null_mut(),
    }
}

fn convert_to_output_encoding(text: String, encoding: OutputEncoding) -> String {
    match encoding {
        OutputEncoding::Unicode => text,
        OutputEncoding::CompositeUnicode => text.nfd().collect(),
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_new() -> *mut VitypeEngine {
    Box::into_raw(Box::new(VitypeEngine::new()))
}

#[no_mangle]
pub extern "C" fn vitype_engine_free(engine: *mut VitypeEngine) {
    if !engine.is_null() {
        unsafe {
            drop(Box::from_raw(engine));
        }
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_reset(engine: *mut VitypeEngine) {
    if engine.is_null() {
        return;
    }
    unsafe {
        (*engine).reset();
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_delete_last_character(engine: *mut VitypeEngine) {
    if engine.is_null() {
        return;
    }
    unsafe {
        (*engine).delete_last_character();
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_set_auto_fix_tone(engine: *mut VitypeEngine, enabled: bool) {
    if engine.is_null() {
        return;
    }
    unsafe {
        (*engine).set_auto_fix_tone(enabled);
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_set_free_tone_placement(engine: *mut VitypeEngine, enabled: bool) {
    if engine.is_null() {
        return;
    }
    unsafe {
        (*engine).set_free_tone_placement(enabled);
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_set_input_method(engine: *mut VitypeEngine, method: i32) {
    if engine.is_null() {
        return;
    }
    unsafe {
        let input_method = match method {
            1 => InputMethod::Vni,
            _ => InputMethod::Telex,
        };
        (*engine).set_input_method(input_method);
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_set_output_encoding(engine: *mut VitypeEngine, encoding: i32) {
    if engine.is_null() {
        return;
    }
    unsafe {
        let output_encoding = match encoding {
            1 => OutputEncoding::CompositeUnicode,
            _ => OutputEncoding::Unicode,
        };
        (*engine).set_output_encoding(output_encoding);
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_set_tone_placement(engine: *mut VitypeEngine, placement: i32) {
    if engine.is_null() {
        return;
    }
    unsafe {
        let tone_placement = match placement {
            1 => TonePlacement::NucleusOnly,
            _ => TonePlacement::Orthographic,
        };
        (*engine).set_tone_placement(tone_placement);
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_process(
    engine: *mut VitypeEngine,
    input_utf8: *const c_char,
) -> VitypeTransformResult {
    if engine.is_null() || input_utf8.is_null() {
        return empty_result();
    }

    let input = unsafe { CStr::from_ptr(input_utf8) };
    let input_str = match input.to_str() {
        Ok(value) => value,
        Err(_) => return empty_result(),
    };

    let (action, output_encoding) =
        unsafe { ((*engine).process(input_str), (*engine).output_encoding()) };
    match action {
        Some(action) => {
            let output_text = convert_to_output_encoding(action.text, output_encoding);
            let c_text = CString::new(output_text).unwrap_or_else(|_| CString::new("").unwrap());
            VitypeTransformResult {
                has_action: true,
                delete_count: action.delete_count as i32,
                text: c_text.into_raw(),
            }
        }
        None => empty_result(),
    }
}

#[no_mangle]
pub extern "C" fn vitype_engine_get_buffer_len(engine: *mut VitypeEngine) -> i32 {
    if engine.is_null() {
        return 0;
    }
    unsafe { (*engine).buffer_len() as i32 }
}

#[no_mangle]
pub extern "C" fn vitype_engine_free_string(text: *mut c_char) {
    if text.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(text));
    }
}
