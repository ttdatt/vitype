# Vietnamese VNI Input Method Rules

This document describes the VNI input method rules for ViType, a Vietnamese IME.

## Code Map (Source of Truth)

- Engine entrypoint and shared logic: `src/lib.rs` (`VitypeEngine::process`, tone placement, foreign mode, history)
- VNI-specific behavior: `src/vni.rs` (VNI word boundaries, VNI escape handling, key mapping)
- Shared diacritic helpers: `src/diacritics.rs` (shape + tone application/escape)
- Shared tone tables: `src/common.rs` (`VOWEL_TO_TONED`, `TONED_TO_BASE`)

## Overview

**VNI** (Vietnamese Input) is a Vietnamese input method that uses **number keys** to produce Vietnamese characters with diacritics and tone marks. Unlike Telex (which uses letters), VNI uses digits 0-9, making it intuitive for users who prefer numeric shortcuts.

### Key Differences from Telex

| Feature | Telex | VNI |
|---------|-------|-----|
| Tone: sắc (acute) | `s` | `1` |
| Tone: huyền (grave) | `f` | `2` |
| Tone: hỏi (hook) | `r` | `3` |
| Tone: ngã (tilde) | `x` | `4` |
| Tone: nặng (dot) | `j` | `5` |
| Remove tone | `z` | `0` |
| Circumflex (â, ê, ô) | `aa`, `ee`, `oo` | `a6`, `e6`, `o6` |
| Horn (ơ, ư) | `ow`, `uw` | `o7`, `u7` |
| Breve (ă) | `aw` | `a8` |
| Đ/đ | `dd` | `d9` |

### How ViType Works

1. **Keystroke interception (host app)**: The host intercepts keystrokes and calls the engine per key
2. **Buffer-based processing**: The engine maintains a buffer of the current word being typed
3. **Transform actions**: The engine returns `KeyTransformAction { delete_count, text }` to rewrite output
   - `delete_count`: Number of characters to delete (backspaces)
   - `text`: Replacement text to insert

**Important**: In VNI mode, digit keys (0-9) are **not** word boundaries - they are transform keys.

**Note (important for implementers)**: When the engine returns a `KeyTransformAction`, the *current key* is treated as consumed (i.e., you typically do **not** also insert the raw key). `delete_count` applies to the already-emitted output before inserting `text`.

---

## 1. Consonant Transformations

### 1.1 Đ/đ (D with stroke)

| Input | Output | Rule |
|-------|--------|------|
| `d9`  | đ      | Lowercase d → đ |
| `D9`  | Đ      | Uppercase D → Đ |

**Implementation**: When `9` is typed after `d`, delete 1 character and output `đ`/`Đ`.

**Scope**: This transform only applies when the `d` starts the word. Mid-word `d9` stays literal (e.g., `ad9` → `ad9`).

### 1.2 Free Transform (Non-Adjacent D)

The `d...9` transform works even when **other characters separate d and 9**, as long as there are **no more than 4 characters between** the `d` and the `9` key (the engine searches up to **5 positions back**) and the `d` starts the word. This allows more flexible typing:

| Input | Buffer State | Output | Description |
|-------|--------------|--------|-------------|
| `di9` | **d**i**9** | đi | d...9 → đ (through `i`) |
| `dede9` | **d**e**d**e**9** | deđe | Last d transforms |
| `do9` | **d**o**9** | đo | d...9 → đ (through `o`) |
| `duong9` | **d**u**o**n**g**9 | đuong | d...9 → đ (through `uong`) |

**How it works**:
1. When typing `9`, the system searches backward (up to 5 positions back)
2. If a `d` is found, it transforms to `đ`/`Đ`
3. Any characters between them are preserved in the output

**Examples**:

| Input | Steps | Final Output |
|-------|-------|--------------|
| `di9` | `di` → `9` transforms d → `đi` | đi |
| `dai9` | `dai` → `9` transforms d → `đai` | đai |

**Limitations**:
- Maximum gap: 4 characters between `d` and `9` (search up to 5 positions back)
- The character must be `d`/`D`, not already transformed `đ`/`Đ`
- The `d` must start the word

---

## 1.3 Foreign Mode (Literal Transforms)

When a word is detected as foreign (invalid Vietnamese syllable), the engine enters **foreign mode** for the rest of the word. While in foreign mode:

- All transform keys (`d9`, tone keys `0–5`, and vowel keys `6–8`) are treated as literal characters.
- Transform behavior resumes after a word boundary (space or punctuation). (Digits are **not** treated as word boundaries in VNI, even in foreign mode.)

**Foreign detection rules (high level)**:
- Multiple vowel clusters (e.g., `aba1` → `aba1`)
- A consonant after the last vowel that is **not** one of: `p`, `t`, `c`, `ch`, `k`, `m`, `n`, `ng`, `nh`

**Examples**:
- `ab1` → `ab1` (b is not a valid final consonant, so tone key `1` stays literal)
- `am1` → `ám` (m is a valid final consonant, tone applies normally)

---

## 2. Vowel Transformations

### 2.1 Key `6` - Circumflex Vowels (â, ê, ô)

The `6` key adds a circumflex (^) to vowels:

| Input | Output | Description |
|-------|--------|-------------|
| `a6`  | â      | a with circumflex |
| `A6`  | Â      | |
| `e6`  | ê      | e with circumflex |
| `E6`  | Ê      | |
| `o6`  | ô      | o with circumflex |
| `O6`  | Ô      | |

**Note**: `6` only transforms `a`, `e`, `o`. For other vowels (`i`, `u`, `y`), `6` outputs as a literal character.

### 2.2 Key `7` - Horn Vowels (ơ, ư)

The `7` key adds a horn to vowels:

| Input | Output | Description |
|-------|--------|-------------|
| `o7`  | ơ      | o with horn |
| `O7`  | Ơ      | |
| `u7`  | ư      | u with horn |
| `U7`  | Ư      | |

**Note**: `7` only transforms `o`, `u`. For other vowels, `7` outputs as a literal character.

**Special behavior**: The `7` key finds the **last transformable vowel** in the buffer (o/u and their horn/toned variants). For ergonomics, it can skip a single **adjacent** vowel that `7` cannot transform (commonly `i`, `y`, or `a`). This allows typing:

- `oi7` → `ơi`
- `ui7` → `ưi`
- `uoi7` → `ươi` (7 skips `i` and applies the `uo` → `ươ` compound transform)

**No standalone behavior**: Unlike Telex's `w` (which produces `ư` when standalone), `7` alone just outputs `7`.

### 2.3 Key `8` - Breve Vowel (ă)

The `8` key adds a breve to `a`:

| Input | Output | Description |
|-------|--------|-------------|
| `a8`  | ă      | a with breve |
| `A8`  | Ă      | |

**Note**: `8` only transforms `a`. For other vowels, `8` outputs as a literal character.

### 2.4 Free Transform (Non-Adjacent Vowels)

Vowel transforms work even when **consonants separate the vowel and number key**, as long as the vowel is within 4 characters. This is called "free transform":

| Input | Buffer State | Output | Description |
|-------|--------------|--------|-------------|
| `that6` | th**a**t**6** | thât | a...6 → â (through `t`) |
| `thet6` | th**e**t**6** | thêt | e...6 → ê (through `t`) |
| `thot7` | th**o**t**7** | thơt | o...7 → ơ (through `t`) |
| `nam8` | n**a**m**8** | năm | a...8 → ă (through `m`) |

**How it works**:
1. When typing `6`/`7`/`8`, the system searches backward (up to 4 characters)
2. If a transformable vowel is found, it transforms
3. Any characters between them are preserved in the output

**Limitations**:
- Maximum search distance: 4 characters
- Only works for compatible vowel+key combinations (see 2.1-2.3)
- If another vowel appears between the target vowel and the number key, no free transform is applied (except for trailing glides - see Telex rules)

### 2.5 Transform Override Behavior

VNI transform keys can **override** each other on the same vowel. This allows switching between circumflex, horn, and breve without escaping first:

#### Override Matrix

| Current Vowel | + `6` | + `7` | + `8` |
|---------------|-------|-------|-------|
| `a` (base)    | â     | literal `7` | ă |
| `â` (circumflex) | escape → `a6` | literal `7` | ă |
| `ă` (breve)   | â     | literal `7` | escape → `a8` |
| `e` (base)    | ê     | literal `7` | literal `8` |
| `ê` (circumflex) | escape → `e6` | literal `7` | literal `8` |
| `o` (base)    | ô     | ơ     | literal `8` |
| `ô` (circumflex) | escape → `o6` | ơ | literal `8` |
| `ơ` (horn)    | ô     | escape → `o7` | literal `8` |
| `u` (base)    | literal `6` | ư | literal `8` |
| `ư` (horn)    | literal `6` | escape → `u7` | literal `8` |

#### Override Examples

| Input | Steps | Final Output | Description |
|-------|-------|--------------|-------------|
| `o67` | o → ô → ơ | ơ | Circumflex overridden by horn |
| `o76` | o → ơ → ô | ô | Horn overridden by circumflex |
| `a68` | a → â → ă | ă | Circumflex overridden by breve |
| `a86` | a → ă → â | â | Breve overridden by circumflex |
| `a67` | a → â → â7 | â7 | `7` can't transform `â`, outputs literal |
| `e67` | e → ê → ê7 | ê7 | `7` can't transform `ê`, outputs literal |

### 2.6 Compound UO7 → ƯƠ/ươ

The sequence `uo7` is treated as a compound transform that produces `ươ`:

| Input | Output |
|-------|--------|
| `uo7` | ươ     |
| `UO7` | ƯƠ     |
| `Uo7` | Ươ     |

Additional ergonomic variants:

| Input | Output | Description |
|-------|--------|-------------|
| `uu7` | ưu     | e.g., `huu7` → `hưu` |
| `ou7` | ươ     | e.g., `hou7` → `hươ` |
| `uou7` | ươu   | e.g., `huou7` → `hươu` |
| `uoi7` | ươi   | e.g., `nguoi7` → `người` |
| `ua7` | ưa     | e.g., `mua7` → `mưa` |
| `u7a` | ưa     | e.g., `mu7a` → `mưa` |

Tone keys typed before the compound `7` still land on `ơ` (e.g., `hu2o7` → `hườ`, `huo1u7` / `hu71ou7` → `hướu`).

**Escape**: `uo77` → `uo7`, `uoi77` → `uoi7`, `u7a7` → `ua7`

**Limitations**:
- If both `u` and `o` already have tone marks, the compound does not apply (ambiguous).
- Does not apply when `u` is part of the `qu` consonant cluster (e.g., `quo7` → `quơ`, `qua8` → `quă`)

### 2.7 UO + Final Consonant + 7 → ƯƠ + Final Consonant

For convenience, ViType supports typing the final consonant **before** `7` and still getting the `uo` → `ươ` compound behavior.

| Input | Output | Description |
|-------|--------|-------------|
| `uoc7` | ươc | `7` reaches back over the final consonant |
| `uoc71` | ước | Tone applies to `ơ` |
| `uoc57` | ược | Tone can be typed before `7` and is preserved |
| `d9uoc7` | đươc | Works with consonant prefix |

### 2.8 Transforms on Already-Toned Vowels

Transform keys can modify vowels that already have tone marks:

| Input (toned) | + 6 | + 7 | + 8 |
|---------------|-----|-----|-----|
| á             | ấ   | -   | ắ   |
| à             | ầ   | -   | ằ   |
| ả             | ẩ   | -   | ẳ   |
| ã             | ẫ   | -   | ẵ   |
| ạ             | ậ   | -   | ặ   |
| ó             | ố   | ớ   | -   |
| ò             | ồ   | ờ   | -   |
| ỏ             | ổ   | ở   | -   |
| õ             | ỗ   | ỡ   | -   |
| ọ             | ộ   | ợ   | -   |
| ú             | -   | ứ   | -   |
| ù             | -   | ừ   | -   |
| ủ             | -   | ử   | -   |
| ũ             | -   | ữ   | -   |
| ụ             | -   | ự   | -   |

This also works for override transforms (e.g., `ố` + `7` → `ớ`).

---

## 3. Tone Marks

### 3.1 Tone Keys

| Key | Vietnamese Name | Mark Type | Unicode Name | Example |
|-----|-----------------|-----------|--------------|---------|
| `1` | sắc             | ´ (acute) | ACUTE        | a1 → á  |
| `2` | huyền           | ` (grave) | GRAVE        | a2 → à  |
| `3` | hỏi             | ̉ (hook)   | HOOK ABOVE   | a3 → ả  |
| `4` | ngã             | ~ (tilde) | TILDE        | a4 → ã  |
| `5` | nặng            | ̣ (dot)    | DOT BELOW    | a5 → ạ  |
| `0` | (remove tone)   | -         | -            | á0 → a  |

### 3.2 Tone Replacement

Typing a different tone key replaces the existing tone:

```
ta + 1 → tá
tá + 2 → tà  (replaces acute with grave)
tà + 3 → tả  (replaces grave with hook)
```

### 3.3 Tone Removal

The `0` key removes any existing tone:

```
tá + 0 → ta
tằ + 0 → tă  (removes tone, keeps breve)
```

### 3.4 Complete Vowel-Tone Mapping Tables

#### Base vowel: a

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| a    | á       | à         | ả       | ã       | ạ        |
| A    | Á       | À         | Ả       | Ã       | Ạ        |

#### Base vowel: ă (a with breve)

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| ă    | ắ       | ằ         | ẳ       | ẵ       | ặ        |
| Ă    | Ắ       | Ằ         | Ẳ       | Ẵ       | Ặ        |

#### Base vowel: â (a with circumflex)

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| â    | ấ       | ầ         | ẩ       | ẫ       | ậ        |
| Â    | Ấ       | Ầ         | Ẩ       | Ẫ       | Ậ        |

#### Base vowel: e

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| e    | é       | è         | ẻ       | ẽ       | ẹ        |
| E    | É       | È         | Ẻ       | Ẽ       | Ẹ        |

#### Base vowel: ê (e with circumflex)

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| ê    | ế       | ề         | ể       | ễ       | ệ        |
| Ê    | Ế       | Ề         | Ể       | Ễ       | Ệ        |

#### Base vowel: i

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| i    | í       | ì         | ỉ       | ĩ       | ị        |
| I    | Í       | Ì         | Ỉ       | Ĩ       | Ị        |

#### Base vowel: o

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| o    | ó       | ò         | ỏ       | õ       | ọ        |
| O    | Ó       | Ò         | Ỏ       | Õ       | Ọ        |

#### Base vowel: ô (o with circumflex)

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| ô    | ố       | ồ         | ổ       | ỗ       | ộ        |
| Ô    | Ố       | Ồ         | Ổ       | Ỗ       | Ộ        |

#### Base vowel: ơ (o with horn)

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| ơ    | ớ       | ờ         | ở       | ỡ       | ợ        |
| Ơ    | Ớ       | Ờ         | Ở       | Ỡ       | Ợ        |

#### Base vowel: u

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| u    | ú       | ù         | ủ       | ũ       | ụ        |
| U    | Ú       | Ù         | Ủ       | Ũ       | Ụ        |

#### Base vowel: ư (u with horn)

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| ư    | ứ       | ừ         | ử       | ữ       | ự        |
| Ư    | Ứ       | Ừ         | Ử       | Ữ       | Ự        |

#### Base vowel: y

| Base | 1 (sắc) | 2 (huyền) | 3 (hỏi) | 4 (ngã) | 5 (nặng) |
|------|---------|-----------|---------|---------|----------|
| y    | ý       | ỳ         | ỷ       | ỹ       | ỵ        |
| Y    | Ý       | Ỳ         | Ỷ       | Ỹ       | Ỵ        |

**Total**: 12 base vowels × 5 tones × 2 cases = **120 toned vowels**

---

## 4. Tone Placement Rules

Vietnamese has specific orthographic rules for where tone marks are placed in vowel clusters. These rules are identical to Telex.

ViType also supports a **Tone Placement Mode** setting:
- **Orthographic** (default): follow standard Vietnamese orthography
- **Nucleus-only**: put the tone on the syllable nucleus in ambiguous 2-vowel clusters (notably `oa`/`oe` and `uy`)

### 4.1 Vietnamese Syllable Structure

A Vietnamese syllable has the structure:

```
[Initial Consonant] + [Pre-glide] + NUCLEUS + [Post-glide] + [Final Consonant]
```

Where:
- **Pre-glide**: `u` or `o` (can act as glides before the nucleus)
- **NUCLEUS**: The main vowel that carries the tone
- **Post-glide**: `i`, `y`, or `u` (can act as glides after the nucleus)

### 4.1.1 Valid Vowel Clusters for Tone Marks

Tone marks are only applied when the **effective vowel cluster** (after `qu`/`gi` skips) is a valid Vietnamese cluster. If the cluster is not valid, tone keys are treated as literal characters.

**Valid 2-letter clusters**:

`ai`, `ao`, `au`, `ay`  
`âu`, `ây`  
`eo`, `êu`  
`iu`  
`ia`, `iê`, `yê`  
`oa`, `oă`, `oe`, `oi`, `ôi`, `ơi`  
`ua`, `uô`, `uâ`, `uê`  
`ui`, `uy`  
`ưa`, `ươ`, `ưi`, `ưu`

**Valid 3-letter clusters**:

`iêu`, `yêu`  
`oai`, `oay`  
`uôi`  
`uya`, `uyê`  
`ươi`, `ươu`

**Note**: Non-accented variants of any accented cluster are also valid (e.g., `êu` → `eu`, `ươ` → `uo`, `ươu` → `uou`). Single vowels always accept tones.
When **Free Tone Placement** is enabled, this cluster validation is bypassed.

### 4.2 Nucleus-Only Vowels

These vowels can **ONLY** be syllable nuclei - they can never act as glides:

| Base | With tones |
|------|------------|
| ă    | ắ, ằ, ẳ, ẵ, ặ |
| â    | ấ, ầ, ẩ, ẫ, ậ |
| ê    | ế, ề, ể, ễ, ệ |
| ô    | ố, ồ, ổ, ỗ, ộ |
| ơ    | ớ, ờ, ở, ỡ, ợ |
| ư    | ứ, ừ, ử, ữ, ự |

### 4.3 Tone Placement Algorithm

The algorithm finds the target vowel in this priority order:

1. **Single vowel** → that vowel takes the tone
2. **Nucleus-only vowel present** → that vowel takes the tone (if multiple, the **last** one)
3. **Two regular vowels** → **second** vowel if followed by a final consonant; otherwise **first**
4. **Three or more regular vowels** → **middle** vowel takes the tone

**Nucleus-only mode override (2-vowel clusters):**
- `oa` / `oe` → tone on `a` / `e` (e.g., `hoa1` → `hoá`, `khoe3` → `khoẻ`)
- `uy` → tone on `y` (e.g., `uy1` → `uý`)

### 4.4 Tone Placement Examples

| Word | Input | Vowels | Rule Applied | Result |
|------|-------|--------|--------------|--------|
| tá | `ta` + `1` | a | Single vowel | t**á** |
| mùa | `mua` + `2` | u, a | Two vowels → first | m**ù**a |
| hóa | `hoa` + `1` | o, a | Two vowels → first (open syllable) | h**ó**a |
| toàn | `toan` + `2` | o, a | Two vowels + consonant → second | to**à**n |
| tiến | `tie6n` + `1` | i, ê | ê is nucleus-only | ti**ế**n |
| muốn | `muo6n` + `1` | u, ô | ô is nucleus-only | mu**ố**n |
| khuỷa | `khuya` + `3` | u, y, a | Three vowels → middle | khu**ỷ**a |
| người | `ngu7o7i` + `2` | ư, ơ, i | ơ is nucleus-only (last) | ngư**ờ**i |
| thật | `that6` + `5` | â | â is nucleus-only | th**ậ**t |
| nắm | `na8m` + `1` | ă | ă is nucleus-only | n**ắ**m |

### 4.5 Consonant Cluster Exceptions

Some consonant clusters include vowel-like characters that should **not** be treated as vowels for tone placement.

#### 4.5.1 The `qu` Cluster

The `u` immediately following `q` is part of the consonant onset, not a syllable vowel:

| Input | Vowels for Tone Placement | Result |
|-------|---------------------------|--------|
| `qua1` | a (u is skipped) | quá |
| `qua2` | a (u is skipped) | quà |
| `quye6n2` | y, ê (u is skipped) | quyền |
| `quo6c1` | ô (u is skipped) | quốc |

#### 4.5.2 The `uy` Vowel Cluster

The `uy` vowel cluster has special tone placement rules, depending on the **Tone Placement Mode**:

- **Orthographic** (default):
  - **`uy` alone** (no final consonant): tone goes on `u` → `úy`
  - **`uy` + consonant(s)**: tone goes on `y` → `uýnh`, `uýt`, etc.
- **Nucleus-only**:
  - Tone always goes on `y`: `uý`, `uýnh`, `uýt`, etc.

| Input | Has Final Consonant | Tone Position | Result |
|-------|---------------------|---------------|--------|
| `uy1` | No | u | úy |
| `uynh1` | Yes (nh) | y | uýnh |
| `uyt1` | Yes (t) | y | uýt |
| `huynh2` | Yes (nh) | y | huỳnh |

**Nucleus-only mode** example: `uy1` → `uý` (tone on `y`).

#### 4.5.3 The `gi` Cluster

The `gi` cluster has conditional behavior depending on what follows:

- **`gi` alone** (no vowel after `i`): `i` is treated as a vowel, tone goes on `i`
- **`gi` + vowel(s)**: `gi` acts as a consonant cluster, `i` is skipped

| Input | `i` treated as | Vowels for Tone | Result |
|-------|----------------|-----------------|--------|
| `gi1` | vowel | i | gí |
| `gi2` | vowel | i | gì |
| `gia1` | consonant (skipped) | a | giá |
| `gio1` | consonant (skipped) | o | gió |

### 4.6 Auto Fix Tone (Dynamic Tone Repositioning)

When **Auto Fix Tone** is enabled (default: on), the tone mark is automatically repositioned to the correct vowel as you type additional vowels.

| Input Sequence | Buffer State | Result | Explanation |
|----------------|--------------|--------|-------------|
| `hoa` + `2` | hòa | hòa | 2 vowels → tone on 1st (o) |
| `hòa` + `i` | hoài | hoài | 3 vowels → tone moves to middle (a) |
| `hòa` + `n` | hoàn | hoàn | 2 vowels + consonant → tone moves to 2nd (a) |

Auto Fix Tone also includes a structural fix for invalid `ơ` clusters: when a standalone `ơ` (from `o7`, not preceded by `ư`) is followed by a vowel other than `i`, the horn is removed (`ơ` → `o`) before continuing normal tone placement.

| Input Sequence | Result | Explanation |
|----------------|--------|-------------|
| `ho7a` | hoa | standalone `ơ` before `a` is normalized to `o` |
| `ho7a85c` | hoặc | prevents invalid `hơă...` sequence |
| `ho7i` | hơi | `ơi` is valid, so horn is kept |
| `hu7o7u` | hươu | `ươ` cluster is preserved (`ơ` is preceded by `ư`) |

---

## 5. Escape Sequences (Double-Key Undo)

### 5.1 Mechanism

Pressing the same transform key again **undoes** the transformation and outputs the literal key.

### 5.2 Consonant Escape

| Sequence | Intermediate | Final | Explanation |
|----------|--------------|-------|-------------|
| `d99`    | đ            | d9    | đ + 9 → d9  |
| `D99`    | Đ            | D9    | Đ + 9 → D9  |

### 5.3 Vowel Transform Escapes

| Sequence | Intermediate | Final | Explanation |
|----------|--------------|-------|-------------|
| `a66`    | â            | a6    | â + 6 → a6  |
| `e66`    | ê            | e6    | ê + 6 → e6  |
| `o66`    | ô            | o6    | ô + 6 → o6  |
| `o77`    | ơ            | o7    | ơ + 7 → o7  |
| `u77`    | ư            | u7    | ư + 7 → u7  |
| `a88`    | ă            | a8    | ă + 8 → a8  |

### 5.4 Tone Escapes

| Sequence | Intermediate | Final | Explanation |
|----------|--------------|-------|-------------|
| `ta11`   | tá           | ta1   | á + 1 → a1  |
| `ta22`   | tà           | ta2   | à + 2 → a2  |
| `ta33`   | tả           | ta3   | ả + 3 → a3  |
| `ta44`   | tã           | ta4   | ã + 4 → a4  |
| `ta55`   | tạ           | ta5   | ạ + 5 → a5  |
| `chan11` | chán         | chan1 | Tone escape works with trailing consonants |

### 5.5 Toned Vowel Transform Escapes

When a vowel has both a transform and a tone, the escape preserves the tone on the base:

| Transformed | + escape key | Result |
|-------------|--------------|--------|
| ắ (ă + 1)   | + 8          | á8     |
| ằ (ă + 2)   | + 8          | à8     |
| ấ (â + 1)   | + 6          | á6     |
| ề (ê + 2)   | + 6          | è6     |
| ớ (ơ + 1)   | + 7          | ó7     |
| ừ (ư + 2)   | + 7          | ù7     |

### 5.6 Repeated Escape Keys

After an escape, repeating the **same** key keeps appending the literal key.
Transforms are suppressed until a word boundary.

| Sequence | Final | Explanation |
|----------|-------|-------------|
| `chan111` | chan11 | 1 → tone, 11 → escape, 1 → literal |
| `a666` | a66 | a6 → â, a66 → a6 (escape), 6 → literal |
| `d999` | d99 | d9 → đ, d99 → d9 (escape), 9 → literal |

---

## 6. Word Boundaries

These characters reset the internal buffer, ending the current word context:

### 6.1 Whitespace
- Space (` `)
- Newline (`\n`)
- Tab (`\t`)

### 6.2 Punctuation
- Comma (`,`)
- Period (`.`)
- Semicolon (`;`)
- Colon (`:`)
- Exclamation (`!`)
- Question (`?`)
- Quotes (`"`, `'`)
- Slashes (`/`, `\`)

### 6.3 Brackets
- Parentheses (`(`, `)`)
- Square brackets (`[`, `]`)
- Curly braces (`{`, `}`)
- Angle brackets (`<`, `>`)

### 6.4 Symbols
- Hyphen/dash (`-`)
- Underscore (`_`)
- At sign (`@`)
- Hash (`#`)
- Dollar (`$`)
- Percent (`%`)
- Caret (`^`)
- Ampersand (`&`)
- Asterisk (`*`)
- Equals (`=`)
- Plus (`+`)
- Backtick (`` ` ``)
- Tilde (`~`)
- Pipe (`|`)

### 6.5 Numbers in VNI Mode

**Important difference from Telex**: In VNI mode, digits `0-9` are **NOT** word boundaries. They are transform/tone keys.

---

## 7. Case Preservation Rules

### 7.1 Consonant đ

The case of `đ` is determined by the `d`:

| Input | Output | Rule |
|-------|--------|------|
| `d9`  | đ      | Lowercase d → đ |
| `D9`  | Đ      | Uppercase D → Đ |

### 7.2 Vowel Transforms

The case follows the **base vowel** being transformed:

| Input | Output | Rule |
|-------|--------|------|
| `a6`  | â      | Lowercase base |
| `A6`  | Â      | Uppercase base |
| `o7`  | ơ      | Lowercase base |
| `O7`  | Ơ      | Uppercase base |

### 7.3 Tone Marks

Tone marks preserve the case of the target vowel:

| Input | Output | Rule |
|-------|--------|------|
| `a1`  | á      | Lowercase 'a' → lowercase result |
| `A1`  | Á      | Uppercase 'A' → uppercase result |

---

## 8. Implementation Notes

This section is descriptive and may lag behind refactors. When in doubt, treat the **behavioral rules** above as normative and consult the **Code Map** at the top of this document for the current implementation.

### 8.1 VNI-Specific Data Structures

```rust
// VNI tone keys (numbers)
static VNI_TONE_KEYS: Lazy<HashSet<char>> = Lazy::new(|| {
    HashSet::from(['0', '1', '2', '3', '4', '5'])
});

// VNI tone key mapping: number -> Telex equivalent
static VNI_TONE_MAP: Lazy<HashMap<char, char>> = Lazy::new(|| {
    HashMap::from([
        ('1', 's'), // sắc
        ('2', 'f'), // huyền
        ('3', 'r'), // hỏi
        ('4', 'x'), // ngã
        ('5', 'j'), // nặng
        ('0', 'z'), // remove tone
    ])
});

// VNI vowel transform keys
static VNI_TRANSFORM_KEYS: Lazy<HashSet<char>> = Lazy::new(|| {
    HashSet::from(['6', '7', '8', '9'])
});

// VNI vowel transforms: key -> [(from, to)] pairs
static VNI_VOWEL_TRANSFORMS: Lazy<HashMap<char, Vec<(char, char)>>> = Lazy::new(|| {
    HashMap::from([
        ('6', vec![  // Circumflex
            ('a', 'â'), ('A', 'Â'),
            ('e', 'ê'), ('E', 'Ê'),
            ('o', 'ô'), ('O', 'Ô'),
            // Override from horn/breve
            ('ơ', 'ô'), ('Ơ', 'Ô'),
            ('ă', 'â'), ('Ă', 'Â'),
        ]),
        ('7', vec![  // Horn
            ('o', 'ơ'), ('O', 'Ơ'),
            ('u', 'ư'), ('U', 'Ư'),
            // Override from circumflex
            ('ô', 'ơ'), ('Ô', 'Ơ'),
        ]),
        ('8', vec![  // Breve
            ('a', 'ă'), ('A', 'Ă'),
            // Override from circumflex
            ('â', 'ă'), ('Â', 'Ă'),
        ]),
    ])
});
```

### 8.2 Processing Order

The `VitypeEngine::process` method for VNI follows this order:

1. **Word boundary check** → Commit the current word into a small internal history window, clear the active word buffers, and return `nil` (digits excluded). For `Enter` (`\r`/`\n`), clear the history window too.
2. **Escape sequence check** → Return undo action if matched
3. **Append to buffer**
4. **Consonant transform** → Check for `d9` → `đ`
5. **Vowel transform** → Check for `6`/`7`/`8` keys
6. **Tone mark** → Check for `1`/`2`/`3`/`4`/`5`/`0` keys
7. **Auto Fix Tone** → Reposition tone / normalize vowel structure if needed (when enabled)
8. **Invalid syllable check** → Revert to raw text and enter foreign mode if needed

Notes:
- The engine keeps a small history (currently **3 words**) so that if the user **backspaces across a word boundary**, the previous word can be restored into the active buffer and VNI tone/transform keys can still be applied.
- Pressing `Enter` clears this history window, so boundary-aware backspace restore is disabled across line breaks.

### 8.3 Key Differences from Telex Processing

| Aspect | Telex | VNI |
|--------|-------|-----|
| Tone keys | `s`, `f`, `r`, `x`, `j`, `z` | `1`, `2`, `3`, `4`, `5`, `0` |
| Circumflex | Double vowel (`aa`, `ee`, `oo`) | Vowel + `6` |
| Horn | `w` after `o`/`u` | `7` after `o`/`u` |
| Breve | `w` after `a` | `8` after `a` |
| Đ transform | `dd` | `d9` |
| Word boundaries | Include digits | Exclude digits |
| Standalone key → ư | `w` → ư | `7` → `7` (no transform) |
| Transform override | `w`→`a` (ă→â), `w`→`o` (ơ→ô) | `6`↔`7`↔`8` can override |

### 8.4 C FFI Surface

```c
// Set input method (0 = Telex, 1 = VNI)
void vitype_engine_set_input_method(VitypeEngine *engine, int32_t method);
void vitype_engine_set_free_tone_placement(VitypeEngine *engine, bool enabled);
```

---

## 9. Quick Reference

### 9.1 All VNI Transform Keys

| Key | Function |
|-----|----------|
| `9` | (after d) → đ |
| `6` | (after a/e/o) → â/ê/ô (circumflex) |
| `7` | (after o/u) → ơ/ư (horn) |
| `8` | (after a) → ă (breve) |
| `1` | Apply sắc tone (´) |
| `2` | Apply huyền tone (`) |
| `3` | Apply hỏi tone (hook) |
| `4` | Apply ngã tone (~) |
| `5` | Apply nặng tone (dot) |
| `0` | Remove tone |

### 9.2 Common Vietnamese Words - VNI Input Examples

| Word | VNI Input | Steps |
|------|-----------|-------|
| việt | `vie6t5` | v→i→e→ê→t→ệ |
| nam | `nam` | n→a→m |
| năm | `na8m` | n→a→ă→m |
| đẹp | `d9e5p` | d→đ→e→ẹ→p |
| đi | `di9` | d→i→**đi** (free transform) |
| người | `ngu7o7i2` | n→g→u→**ư**→o→**ơ**→i→**ờ** |
| nước | `nu7o71c` | n→u→**ư**→o→**ơ**→**ớ**→c |
| được | `d9u7o75c` | d→**đ**→u→**ư**→o→**ơ**→**ợ**→c |
| tiếng | `tie6ng1` | t→i→e→**ê**→n→g→**ế** |
| quốc | `quo6c1` | q→u→o→**ô**→c→**ố** |
| học | `ho5c` | h→o→**ọ**→c |
| thật | `that65` | t→h→a→t→**â**→**ậ** (free transform) |
| chán | `chan1` | c→h→a→n→**á** |
| quá | `qua1` | q→u→a→**á** (qu cluster) |
| huỳnh | `huynh2` | h→u→y→n→h→**ỳ** (uy + consonant) |
| gì | `gi2` | g→i→**ì** (gi alone) |
| giá | `gia1` | g→i→a→**á** (gi + vowel) |
| giữ | `giu74` | g→i→u→**ư**→**ữ** |

### 9.3 Transform Comparison: Telex vs VNI

| Vietnamese | Telex | VNI |
|------------|-------|-----|
| đẹp | `ddejp` | `d9e5p` |
| việt | `vieejt` | `vie6t5` |
| người | `nguwowif` | `ngu7o7i2` |
| năm | `nawm` | `na8m` |
| quốc | `quoocs` | `quo6c1` |
| huyền | `huyeenf` | `huye6n2` |
