# Vietnamese Telex Input Method Rules

This document describes the Telex input method rules implemented in **ViType-core** (`VitypeEngine`).

## Code Map (Source of Truth)

- Engine entrypoint and shared logic: `src/lib.rs` (`VitypeEngine::process`, tone placement, foreign mode, history)
- Telex-specific behavior: `src/telex.rs` (Telex word boundaries, Telex escape handling)
- Shared diacritic helpers: `src/diacritics.rs` (shape + tone application/escape)
- Shared tone tables: `src/common.rs` (`VOWEL_TO_TONED`, `TONED_TO_BASE`)

## Overview

**Telex** is a Vietnamese input method that uses letter combinations to produce Vietnamese characters with diacritics and tone marks. Unlike VNI (which uses numbers), Telex uses only letters, making it faster for touch typists.

### How the Engine Works (Host-Agnostic)

1. **Keystroke interception (host app)**: The host intercepts keystrokes and calls the engine per key
2. **Buffer-based processing**: The engine maintains a buffer of the current word being typed
3. **Transform actions**: The engine returns `KeyTransformAction { delete_count, text }` to rewrite output
   - `delete_count`: Number of characters to delete (backspaces)
   - `text`: Replacement text to insert

**Note (important for implementers)**: When the engine returns a `KeyTransformAction`, the *current key* is treated as consumed (i.e., you typically do **not** also insert the raw key). `delete_count` applies to the already-emitted output before inserting `text`.

**Word boundaries (Telex)**: whitespace, ASCII punctuation, and ASCII digits. (Digits are boundaries in Telex; they are *not* boundaries in VNI.)

---

## 1. Consonant Transformations

### 1.1 Đ/đ (D with stroke)

| Input | Output | Rule |
|-------|--------|------|
| `dd`  | đ      | First 'd' determines case |
| `DD`  | Đ      | |
| `Dd`  | Đ      | Uppercase first 'd' → Đ |
| `dD`  | đ      | Lowercase first 'd' → đ |

**Implementation**: When second `d` is typed, delete 1 character and output `đ`/`Đ`.

**Scope**: This transform only applies when the first `d` starts the word. Mid-word `dd` stays literal (e.g., `add` → `add`).

### 1.1.1 Free Transform (Non-Adjacent D)

The `dd` → `đ` transform works even when **other characters separate the two d's**, as long as the first `d` is within **4 characters between them** (i.e., the engine searches up to **5 positions back**) and at the start of the word. This allows more flexible typing:

| Input | Buffer State | Output | Description |
|-------|--------------|--------|-------------|
| `did` | **d**i**d** | đi | d...d → đ (through `i`) |
| `dede` | **d**e**d**e | đeđe | First d...d → đ, then second d...d |
| `dod` | **d**o**d** | đo | d...d → đ (through `o`) |

**How it works**:
1. When typing `d`, the system searches backward (up to 5 positions back)
2. If a previous `d` is found, they merge into `đ`/`Đ`
3. Any characters between them are preserved in the output

**Examples**:

| Input | Steps | Final Output |
|-------|-------|--------------|
| `did` | `di` → second `d` merges → `đi` | đi |
| `daid` | `dai` → second `d` merges → `đai` | đai |
| `duongd` | `duong` → second `d` merges → `đuong` | đuong |

**Limitations**:
- Maximum gap: 4 characters between the two `d` keys (search up to 5 positions back)
- The first character must be `d`/`D`, not already transformed `đ`/`Đ`
- The first `d` must start the word

### 1.2 Foreign Consonants (z, w, j, f)

These letters serve dual purposes: they act as **consonants** when they appear before vowels, and as **tone/transform keys** when they appear after vowels.

#### Position-Based Behavior

| Letter | Before Vowel (Consonant) | After Vowel (Tone/Transform) |
|--------|--------------------------|------------------------------|
| `z`    | `za` → za                | `asz` → a (remove tone)      |
| `j`    | `ja` → ja                | `aj` → ạ (nặng tone)         |
| `f`    | `fa` → fa                | `af` → à (huyền tone)        |
| `w`    | (special, see below)     | `aw` → ă (breve transform)   |

**Note**: Telex `z` only removes tone when there is an existing tone to remove; otherwise it is treated as a literal `z` (so you can type words containing `z`).

#### Z as Consonant

Z behaves like any other consonant (n, m, k) when it appears before a vowel:

| Input | Output | Description |
|-------|--------|-------------|
| `za`  | za     | z consonant + a vowel |
| `zas` | zá     | z consonant + á (sắc tone) |
| `zeef`| zề     | z consonant + ề (ê + huyền) |
| `zaos`| záo    | z consonant + áo |
| `zuynhf` | zuỳnh | z consonant + uỳnh |

#### J as Consonant

J behaves like a normal consonant when it appears before a vowel:

| Input | Output | Description |
|-------|--------|-------------|
| `ja`  | ja     | j consonant + a vowel |
| `jas` | já     | j consonant + á |
| `jaj` | jạ     | j consonant + ạ (j applies nặng) |
| `jeef`| jề     | j consonant + ề |

#### F as Consonant

F behaves like a normal consonant when it appears before a vowel:

| Input | Output | Description |
|-------|--------|-------------|
| `fa`  | fa     | f consonant + a vowel |
| `fas` | fá     | f consonant + á |
| `faf` | fà     | f consonant + à (f applies huyền) |
| `feef`| fề     | f consonant + ề |

#### W as Consonant (After Escape)

W has special behavior because it also produces `ư` when standalone:

| Input | Output | Description |
|-------|--------|-------------|
| `w`   | ư      | Standalone w becomes ư |
| `wa`  | ưa     | w → ư, then a appended |
| `ww`  | w      | Escape: produces literal w |
| `wwa` | wa     | After escape, w is consonant + a |
| `wwas`| was    | After escape, tone keys are literal |
| `wwifi` | wifi | w consonant + ifi (foreign word) |
| `wwuw`| wuw    | After escape, vowel transforms are literal |

**Use case**: Typing foreign words like "wifi", "web", "window":
- `wwifi` → wifi
- `wweb` → web  
- `wwindow` → window

#### Mixed Usage with W Transform

Foreign consonants can be combined with w transforms on following vowels:

| Input | Output | Description |
|-------|--------|-------------|
| `zuw` | zư     | z consonant + ư |
| `zaw` | ză     | z consonant + ă |
| `zow` | zơ     | z consonant + ơ |
| `juw` | jư     | j consonant + ư |
| `fuw` | fư     | f consonant + ư |

---

## 1.3 Foreign Mode (Literal Transforms)

When a word is detected as foreign (invalid Vietnamese syllable), the engine enters **foreign mode** for the rest of the word. While in foreign mode:

- All transform keys (`dd`, tone keys, `w` compounds) are treated as literal characters.
- Transform behavior resumes after a word boundary (whitespace, punctuation, or digit).

**Foreign detection rules (high level)**:
- Multiple vowel clusters (e.g., `abes` → `abes`)
- A consonant after the last vowel that is **not** one of: `p`, `t`, `c`, `ch`, `k`, `m`, `n`, `ng`, `nh`

**Examples**:
- `abs` → `abs` (b is not a valid final consonant, so tone key `s` stays literal)
- `ams` → `ám` (m is a valid final consonant, tone applies normally)

---

## 2. Vowel Transformations

### 2.1 Doubling (Circumflex Vowels)

Typing a vowel twice produces the circumflex version:

| Input | Output | Description |
|-------|--------|-------------|
| `aa`  | â      | a with circumflex |
| `AA`  | Â      | |
| `Aa`  | Â      | Case follows first vowel |
| `aA`  | â      | Case follows first vowel |
| `ee`  | ê      | e with circumflex |
| `EE`  | Ê      | |
| `oo`  | ô      | o with circumflex |
| `OO`  | Ô      | |

### 2.1.1 Free Transform (Non-Adjacent Vowels)

Circumflex transforms work even when **consonants separate the two vowels**, as long as the matching vowel is within 4 characters. This is called "free transform" and allows more flexible typing:

| Input | Buffer State | Output | Description |
|-------|--------------|--------|-------------|
| `thataj` | th**a**t**a**j | thật | a...a → â (through `t`), then j → ậ |
| `thetes` | th**e**t**e**s | thết | e...e → ê (through `t`), then s → ế |
| `thotos` | th**o**t**o**s | thốt | o...o → ô (through `t`), then s → ố |

**How it works**:
1. When typing the second `a`/`e`/`o`, the system searches backward (up to 4 characters)
2. If a matching base vowel is found, they merge into the circumflex version
3. Any characters between them are preserved in the output

**Examples with tone applied after transform**:

| Input | Steps | Final Output |
|-------|-------|--------------|
| `thataj` | `that` → `a` merges → `thât` → `j` applies → `thật` | thật |
| `ngotas` | `ngot` → `a` (no match for `o...a`) → `ngota` → `s` applies | ngotá |
| `ngotof` | `ngot` → `o` merges → `ngôt` → `f` applies → `ngồt` | ngồt |

**Limitations**:
- Maximum search distance: 4 characters
- Only works for `a`→`â`, `e`→`ê`, `o`→`ô` (not `w` transforms)
- The first vowel must be a base vowel (a, e, o), not already transformed
- If another vowel appears between the two matching vowels, no free transform is applied (e.g., `device` stays `device`), except when a trailing glide `i`/`y`/`u` sits immediately before the second vowel (e.g., `thoio` → `thôi`, `dauda` → `đâu`)

### 2.2 W-Transforms (Breve and Horn Vowels)

The `w` key transforms vowels to breve (ă) or horn (ơ, ư) variants:

| Input | Output | Description |
|-------|--------|-------------|
| `aw`  | ă      | a with breve |
| `AW`  | Ă      | |
| `ow`  | ơ      | o with horn |
| `OW`  | Ơ      | |
| `uw`  | ư      | u with horn |
| `UW`  | Ư      | |

**Special behavior**: The `w` key finds the **last transformable vowel** in the buffer (a/o/u and their horn/breve/toned variants), skipping non-w-transformable vowels like `i` or `y`. This allows typing like `tuaw` → `tưa` (though `tuw` → `tư` is more common) and `oiw` → `ơi`.

**Examples**:
- `oiw` → `ơi`
- `uiw` → `ưi`
- `uoiw` → `ươi` (w skips `i` and applies the `uo` → `ươ` compound transform)

**Escape**: `oiww` → `oiw`, `uiww` → `uiw`, `uoiww` → `uoiw`

**Override**: After a `w`-transform on `a` or `o`, the circumflex key can override it on the same vowel:
- `hawa` → `hâ` (ă + a → â)
- `hawysfa` → `hầy` (ằ + a → ầ)
- `howo` → `hô` (ơ + o → ô)
- `howfo` → `hồ` (ờ + o → ồ)

### 2.2.1 Standalone W → Ư/ư

When there is **no vowel available to transform**, `w` is treated as a standalone vowel:

| Input | Output |
|-------|--------|
| `w`   | ư      |
| `W`   | Ư      |
| `tw`  | tư     |

**Escape**: Press `w` again to type a literal `w`:
- `ww` → `w`
- `tww` → `tw`

### 2.2.2 Compound UOW → ƯƠ/ươ

The sequence `uow` is treated as a compound transform that produces `ươ` in one step:

| Input | Output |
|-------|--------|
| `uow` | ươ     |
| `UOW` | ƯƠ     |
| `Uow` | Ươ     |

Additional ergonomic variants are supported:
- `uuw` → `ưu` (e.g., `huuw` → `hưu`)
- `ouw` → `ươ` (e.g., `houw` → `hươ`)
- `uouw` → `ươu` (e.g., `huouw` → `hươu`)
- Works even if the first `u` is already `ư` from an earlier transform (e.g., `huwouw` / `hwouw` → `hươu`)
- Tone keys typed before the compound `w` still land on `ơ` (e.g., `hufow` → `hườ`, `huousw` / `huwsouw` → `hướu`)
- `uaw` → `ưa` (e.g., `muaw` → `mưa`)
- `uwa` → `ưa` (e.g., `muwa` → `mưa`)

**Escape**: `uoww` → `uow`, `uwaw` → `uaw`

**Limitations**:
- If both `u` and `o` already have tone marks, the compound does not apply (ambiguous).
- Does not apply when `u` is part of the `qu` consonant cluster (e.g., `quow` → `quơ`, `quaw` → `quă`)

### 2.2.3 UO + Final Consonant + W → ƯƠ + Final Consonant (e.g., `uocw`)

For convenience, vnkey also supports typing the final consonant **before** `w` and still getting the same `uo` → `ươ` compound behavior.

| Input | Output | Description |
|-------|--------|-------------|
| `uocw` | ươc | `w` reaches back over the final consonant and transforms `uo` → `ươ` |
| `uocws` | ước | Tone applies to `ơ` (nucleus-only, before the final consonant) |
| `dduocw` | đươc | Works with consonant prefix (`dd` → `đ`) |

**Notes / limitations**:
- Only applies when the last vowel before the final consonant cluster is `o` and it is immediately preceded by `u` (i.e., `uo...w`)
- Same `qu` limitation as `uow`
- If a tone key was typed earlier (on `u` or `o`), the compound still applies and preserves the tone on `ơ` (e.g., `uocjw` / `duocjw`)

### 2.3 W-Transform on Already-Toned Vowels

The `w` key can transform vowels that already have tone marks:

| Input (toned) | + w | Output |
|---------------|-----|--------|
| á             | w   | ắ      |
| à             | w   | ằ      |
| ả             | w   | ẳ      |
| ã             | w   | ẵ      |
| ạ             | w   | ặ      |
| ó             | w   | ớ      |
| ò             | w   | ờ      |
| ỏ             | w   | ở      |
| õ             | w   | ỡ      |
| ọ             | w   | ợ      |
| ú             | w   | ứ      |
| ù             | w   | ừ      |
| ủ             | w   | ử      |
| ũ             | w   | ữ      |
| ụ             | w   | ự      |

This also works for `ô` → `ơ` conversions (e.g., `oow` after tone):

| Input | + w | Output |
|-------|-----|--------|
| ố     | w   | ớ      |
| ồ     | w   | ờ      |
| ổ     | w   | ở      |
| ỗ     | w   | ỡ      |
| ộ     | w   | ợ      |

---

## 3. Tone Marks

### 3.1 Tone Keys

| Key | Vietnamese Name | Mark Type | Unicode Name | Example |
|-----|-----------------|-----------|--------------|---------|
| `s` | sắc             | ´ (acute) | ACUTE        | á       |
| `f` | huyền           | ` (grave) | GRAVE        | à       |
| `r` | hỏi             | ̉ (hook)   | HOOK ABOVE   | ả       |
| `x` | ngã             | ~ (tilde) | TILDE        | ã       |
| `j` | nặng            | ̣ (dot)    | DOT BELOW    | ạ       |
| `z` | (remove tone)   | -         | -            | a       |

**Case insensitive**: Both `s` and `S` apply the same tone.

### 3.2 Tone Replacement

Typing a different tone key replaces the existing tone:

```
ta + s → tá
tá + f → tà  (replaces acute with grave)
tà + r → tả  (replaces grave with hook)
```

### 3.3 Tone Removal

The `z` key removes any existing tone:

```
tá + z → ta
tằ + z → tă  (removes tone, keeps breve)
```

### 3.4 Complete Vowel-Tone Mapping Tables

#### Base vowel: a

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| a    | á       | à         | ả       | ã       | ạ        |
| A    | Á       | À         | Ả       | Ã       | Ạ        |

#### Base vowel: ă (a with breve)

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| ă    | ắ       | ằ         | ẳ       | ẵ       | ặ        |
| Ă    | Ắ       | Ằ         | Ẳ       | Ẵ       | Ặ        |

#### Base vowel: â (a with circumflex)

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| â    | ấ       | ầ         | ẩ       | ẫ       | ậ        |
| Â    | Ấ       | Ầ         | Ẩ       | Ẫ       | Ậ        |

#### Base vowel: e

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| e    | é       | è         | ẻ       | ẽ       | ẹ        |
| E    | É       | È         | Ẻ       | Ẽ       | Ẹ        |

#### Base vowel: ê (e with circumflex)

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| ê    | ế       | ề         | ể       | ễ       | ệ        |
| Ê    | Ế       | Ề         | Ể       | Ễ       | Ệ        |

#### Base vowel: i

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| i    | í       | ì         | ỉ       | ĩ       | ị        |
| I    | Í       | Ì         | Ỉ       | Ĩ       | Ị        |

#### Base vowel: o

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| o    | ó       | ò         | ỏ       | õ       | ọ        |
| O    | Ó       | Ò         | Ỏ       | Õ       | Ọ        |

#### Base vowel: ô (o with circumflex)

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| ô    | ố       | ồ         | ổ       | ỗ       | ộ        |
| Ô    | Ố       | Ồ         | Ổ       | Ỗ       | Ộ        |

#### Base vowel: ơ (o with horn)

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| ơ    | ớ       | ờ         | ở       | ỡ       | ợ        |
| Ơ    | Ớ       | Ờ         | Ở       | Ỡ       | Ợ        |

#### Base vowel: u

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| u    | ú       | ù         | ủ       | ũ       | ụ        |
| U    | Ú       | Ù         | Ủ       | Ũ       | Ụ        |

#### Base vowel: ư (u with horn)

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| ư    | ứ       | ừ         | ử       | ữ       | ự        |
| Ư    | Ứ       | Ừ         | Ử       | Ữ       | Ự        |

#### Base vowel: y

| Base | s (sắc) | f (huyền) | r (hỏi) | x (ngã) | j (nặng) |
|------|---------|-----------|---------|---------|----------|
| y    | ý       | ỳ         | ỷ       | ỹ       | ỵ        |
| Y    | Ý       | Ỳ         | Ỷ       | Ỹ       | Ỵ        |

**Total**: 12 base vowels × 5 tones × 2 cases = **120 toned vowels**

---

## 4. Tone Placement Rules

Vietnamese has specific orthographic rules for where tone marks are placed in vowel clusters. This is the most complex part of the implementation.

### 4.1 Vietnamese Syllable Structure

A Vietnamese syllable has the structure:

```
[Initial Consonant] + [Pre-glide] + NUCLEUS + [Post-glide] + [Final Consonant]
```

Where:
- **Pre-glide**: `u` or `o` (can act as glides before the nucleus)
- **NUCLEUS**: The main vowel that carries the tone
- **Post-glide**: `i`, `y`, or `u` (can act as glides after the nucleus)

### 4.1.1 Syllable Validation (Single Vowel Cluster)

Every valid Vietnamese syllable must collapse all vowels into **one contiguous cluster** (after applying `qu`/`gi` consonant-cluster skips). If a word implies **multiple vowel nuclei** (separated vowel clusters), the input is treated as foreign:

- All transformations are reverted to the **original typed text**
- Further transforms are **disabled** until a word boundary

Examples:

| Input | Output | Reason |
|-------|--------|--------|
| `device` | device | Multiple vowel clusters → foreign word |
| `thatae` | thatae | Second vowel cluster invalidates the syllable |
| `thoio` | thôi | Single vowel cluster (`oi`) remains valid |

### 4.1.2 Valid Vowel Clusters for Tone Marks

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

**Total**: 6 bases × (1 + 5 tones) × 2 cases = **72 nucleus-only vowels**

### 4.3 Tone Placement Algorithm

The algorithm finds the target vowel in this priority order:

1. **Single vowel** → that vowel takes the tone
2. **Nucleus-only vowel present** → that vowel takes the tone (if multiple, the **last** one)
3. **Two regular vowels** → **second** vowel if followed by a final consonant; otherwise **first**
4. **Three or more regular vowels** → **middle** vowel takes the tone

### 4.4 Tone Placement Examples

| Word | Input | Vowels | Rule Applied | Result |
|------|-------|--------|--------------|--------|
| tá | `ta` + `s` | a | Single vowel | t**á** |
| mùa | `mua` + `f` | u, a | Two vowels → first | m**ù**a |
| hóa | `hoa` + `s` | o, a | Two vowels → first (open syllable) | h**ó**a |
| toàn | `toan` + `f` | o, a | Two vowels + consonant → second | to**à**n |
| tiến | `tieen` + `s` | i, ê | ê is nucleus-only | ti**ế**n |
| muốn | `muoon` + `s` | u, ô | ô is nucleus-only | mu**ố**n |
| khuỷa | `khuya` + `r` | u, y, a | Three vowels → middle | khu**ỷ**a |
| người | `nguoiw` + `f` | ư, ơ, i | ơ is nucleus-only (last) | ngư**ờ**i |
| hướu | `huowwu` + `s` | ư, ơ, u | ơ is nucleus-only (last) | hư**ớ**u |
| thật | `thaat` + `j` | â | â is nucleus-only | th**ậ**t |
| nắm | `nawm` + `s` | ă | ă is nucleus-only | n**ắ**m |
| quyền | `quyeen` + `f` | u, y, ê | ê is nucleus-only | quy**ề**n |
| hừu | `huwu` + `f` | ư, u | ư is nucleus-only | h**ừ**u |

### 4.5 Why "Last" Nucleus-Only Vowel?

In clusters like `ươ` (both are nucleus-only), the **last** one is the actual nucleus:

```
ngươi = ng + [ư as pre-nucleus] + [ơ as NUCLEUS] + [i as post-glide]
```

The `ư` here acts more like a medial/pre-nucleus element, while `ơ` is the true nucleus.

### 4.6 Consonant Cluster Exceptions

Some consonant clusters include vowel-like characters that should **not** be treated as vowels for tone placement.

#### 4.6.1 The `qu` Cluster

The `u` immediately following `q` is part of the consonant onset, not a syllable vowel:

| Input | Vowels for Tone Placement | Result |
|-------|---------------------------|--------|
| `quas` | a (u is skipped) | quá |
| `quaf` | a (u is skipped) | quà |
| `quyeenf` | y, ê (u is skipped) | quyền |
| `quoocs` | ô (u is skipped) | quốc |

**Without this rule**, `quas` would incorrectly produce `qúa` (tone on `u` as first of two vowels).

#### 4.6.2 The `uy` Vowel Cluster

The `uy` vowel cluster has special tone placement rules, depending on the **Tone Placement Mode**:

- **Orthographic** (default):
  - **`uy` alone** (no final consonant): tone goes on `u` → `úy`
  - **`uy` + consonant(s)**: tone goes on `y` → `uýnh`, `uýt`, etc.
- **Nucleus-only**:
  - Tone always goes on `y` (treat `y` as the nucleus): `uý`, `uýnh`, `uýt`, etc.

| Input | Has Final Consonant | Tone Position | Result |
|-------|---------------------|---------------|--------|
| `uys` | No | u | úy |
| `uynhs` | Yes (nh) | y | uýnh |
| `uyts` | Yes (t) | y | uýt |
| `huynhf` | Yes (nh) | y | huỳnh |
| `quyf` | No | y | quỳ |

**Note**: For `quy`, the `u` after `q` is part of the consonant cluster (see 4.6.1), so `quy` has only one vowel (`y`) and the tone naturally goes on `y`.

**Nucleus-only mode** example: `uys` → `uý` (tone on `y`).

**Without this rule**, `uynhs` would incorrectly produce `úynh` (tone on `u` as first of two vowels).

#### 4.6.3 The `gi` Cluster

The `gi` cluster has conditional behavior depending on what follows:

- **`gi` alone** (no vowel after `i`): `i` is treated as a vowel, tone goes on `i`
- **`gi` + vowel(s)**: `gi` acts as a consonant cluster, `i` is skipped, tone goes on following vowel(s)

| Input | `i` treated as | Vowels for Tone | Result |
|-------|----------------|-----------------|--------|
| `gis` | vowel | i | gí |
| `gif` | vowel | i | gì |
| `gias` | consonant (skipped) | a | giá |
| `gios` | consonant (skipped) | o | gió |
| `gies` | consonant (skipped) | e | gié |
| `gius` | consonant (skipped) | u | giú |
| `giuws` | consonant (skipped) | ư | giứ |
| `giangs` | consonant (skipped) | a | giáng |
| `gieof` | consonant (skipped) | e, o → first | gièo |

**Auto Fix Tone with `gi`**: When typing `gí` then adding a vowel like `a`, the tone automatically repositions:
- `gí` + `a` → `giá` (tone moves from `i` to `a`, and `gi` becomes consonant cluster)

**Without this rule**, `gias` would incorrectly produce `gía` (tone on `i` as first of two vowels).

#### 4.6.4 The `oa` Cluster

The `oa` cluster (and similar `oe`) is the most visible difference between **Orthographic** vs **Nucleus-only** tone placement:

- **Orthographic** (default):
  - `oa` with **no** final consonant → tone on `o`: `hóa`, `hòa`, ...
  - `oa` with a final consonant → tone on `a`: `toàn`, `hoành`, ...
- **Nucleus-only**:
  - Tone always goes on the nucleus (`a`/`e`): `hoá`, `hoà`, `khoẻ`, `toàn`, ...

| Input | Mode | Result |
|-------|------|--------|
| `hoas` | Orthographic | hóa |
| `hoas` | Nucleus-only | hoá |
| `khoer` | Orthographic | khỏe |
| `khoer` | Nucleus-only | khoẻ |
| `toanf` | Orthographic | toàn |
| `toanf` | Nucleus-only | toàn |

**Note**: In **Orthographic** mode, without the “final consonant → second vowel” sub-rule, `toanf` would incorrectly produce `tòan` (tone on `o`).

### 4.7 Auto Fix Tone (Dynamic Tone Repositioning)

When **Auto Fix Tone** is enabled (default: on), the tone mark is automatically repositioned to the correct vowel as you type additional vowels. This allows more natural typing without worrying about tone placement order.

#### 4.7.1 How It Works

When a new vowel or final consonant is added to a word that already has a tone mark, the system:
1. Detects the currently toned vowel
2. Recalculates the correct tone position based on the new vowel cluster
3. Moves the tone if the position has changed

#### 4.7.2 Examples

| Input Sequence | Buffer State | Result | Explanation |
|----------------|--------------|--------|-------------|
| `hoa` + `f` | hòa | hòa | 2 vowels → tone on 1st (o) |
| `hòa` + `i` | hoài | hoài | 3 vowels → tone moves to middle (a) |
| `hòa` + `n` | hoàn | hoàn | 2 vowels + consonant → tone moves to 2nd (a) |
| `mua` + `f` | mùa | mùa | 2 vowels → tone on 1st (u) |
| `mùa` + `i` | muài | muài | 3 vowels → tone moves to middle (a) |
| `tuyetj` + `e` | tuỵet → tuyệt | tuyệt | e→ê creates nucleus-only vowel, tone moves to ê |

**Detailed flow for "hoài":**
``` 
h → o → a → f → i
        ↓   ↓   ↓
       hoa hòa hoài
            │    │
            │    └─ tone moves from ò to à (3 vowels → middle)
            └─ tone applied to o (2 vowels → 1st)
```

#### 4.7.3 Structural Vowel Auto-Fix (`ơ` + vowel)

Auto Fix Tone also includes a structural fix for invalid `ơ` clusters: when a standalone `ơ` (not preceded by `ư`) is followed by a vowel other than `i`, the horn is removed (`ơ` → `o`) before continuing normal tone placement.

| Input Sequence | Result | Explanation |
|----------------|--------|-------------|
| `howa` | hoa | standalone `ơ` before `a` is normalized to `o` |
| `howawjc` | hoặc | prevents invalid `hơă...` sequence |
| `howi` | hơi | `ơi` is valid, so horn is kept |
| `huwouw` | hươu | `ươ` cluster is preserved (`ơ` is preceded by `ư`) |

#### 4.7.4 When Tone Doesn't Move

The tone stays in place when:
- It's already in the correct position
- The toned vowel is a **nucleus-only vowel** (ă, â, ê, ô, ơ, ư) which always takes the tone

| Input Sequence | Buffer State | Result | Explanation |
|----------------|--------------|--------|-------------|
| `tuô` + `s` | tuố | tuố | ô is nucleus-only, takes tone |
| `tuố` + `i` | tuối | tuối | ô remains toned (nucleus-only priority) |
| `ta` + `s` | tá | tá | Single vowel |
| `tá` + `i` | tái | tái | 2 vowels → 1st, tone already correct |

#### 4.7.5 Disabling Auto Fix Tone

Auto Fix Tone can be disabled in the app settings. When disabled:
- Tone marks stay where they were originally placed
- Adding vowels doesn't trigger repositioning
- Users have full manual control over tone placement

| Setting | `hòa` + `i` | Result |
|---------|-------------|--------|
| Enabled (default) | hoài | Tone moves to correct position |
| Disabled | hòai | Tone stays on original vowel |

---

## 5. Escape Sequences (Double-Key Undo)

### 5.1 Mechanism

Pressing the same transform key again **undoes** the transformation and outputs the literal keys.

### 5.2 Consonant Escape

| Sequence | Intermediate | Final | Explanation |
|----------|--------------|-------|-------------|
| `ddd`    | đ            | dd    | đ + d → dd  |
| `DDD`    | Đ            | DD    | Đ + D → DD  |
| `Ddd`    | Đ            | Dd    | Đ + d → Dd  |

### 5.3 Vowel Transform Escapes

| Sequence | Intermediate | Final | Explanation |
|----------|--------------|-------|-------------|
| `aaa`    | â            | aa    | â + a → aa  |
| `eee`    | ê            | ee    | ê + e → ee  |
| `ooo`    | ô            | oo    | ô + o → oo  |
| `aww`    | ă            | aw    | ă + w → aw  |
| `oww`    | ơ            | ow    | ơ + w → ow  |
| `uww`    | ư            | uw    | ư + w → uw  |

Escapes apply to the **last transformed vowel**, even if consonants follow it (e.g., `exxpee` → `expe`).

### 5.4 Tone Escapes

| Sequence | Intermediate | Final | Explanation |
|----------|--------------|-------|-------------|
| `tass`   | tá           | tas   | á + s → as  |
| `taff`   | tà           | taf   | à + f → af  |
| `tarr`   | tả           | tar   | ả + r → ar  |
| `taxx`   | tã           | tax   | ã + x → ax  |
| `tajj`   | tạ           | taj   | ạ + j → aj  |
| `chanss` | chán         | chans | Tone escape works even with trailing consonants |

### 5.5 Toned Vowel Transform Escapes

When a vowel has both a transform and a tone, the escape preserves the tone on the base:

| Sequence | Steps | Final | Explanation |
|----------|-------|-------|-------------|
| `aasaa`  | a→â→ấ→âa | áa | ấ + a → áa (tone moves to base) |
| `awsaww` | a→ă→ắ→ăw | ásw | Wait, let me check... |

Actually, the escape outputs the **original vowel with its tone** plus the key:

| Transformed | + escape key | Result |
|-------------|--------------|--------|
| ắ (ă + s)   | + w          | áw     |
| ằ (ă + f)   | + w          | àw     |
| ấ (â + s)   | + a          | áa     |
| ề (ê + f)   | + e          | èe     |
| ớ (ơ + s)   | + w          | ów     |
| ừ (ư + f)   | + w          | ùw     |

### 5.6 Repeated Escape Keys

After an escape, repeating the **same** key keeps appending the literal key.
Transforms are suppressed until a word boundary.

| Sequence | Final | Explanation |
|----------|-------|-------------|
| `chansss` | chanss | s → tone, ss → escape, s → literal |
| `aaaa` | aaa | aa → â, aaa → aa (escape), a → literal |
| `ddddd` | dddd | dd → đ, ddd → dd (escape), d → literal |
| `wwww` | www | w → ư, ww → w (escape), w → literal |

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

### 6.5 Numbers
- All digits (`0` through `9`)

---

## 7. Case Preservation Rules

### 7.1 Consonant đ

The case of `đ` is determined by the **first** `d`:

| Input | Output | Rule |
|-------|--------|------|
| `dd`  | đ      | First 'd' is lowercase |
| `DD`  | Đ      | First 'D' is uppercase |
| `Dd`  | Đ      | First 'D' is uppercase |
| `dD`  | đ      | First 'd' is lowercase |

### 7.2 Vowel Transforms

The case follows the **base vowel** being transformed (i.e., the vowel already in the buffer). The transform key’s own case is ignored for these transforms.

| Input | Output | Rule |
|-------|--------|------|
| `aa`  | â      | Lowercase base |
| `AA`  | Â      | Uppercase base |
| `aA`  | â      | Lowercase base (second key case ignored) |
| `Aa`  | Â      | Uppercase base |

### 7.3 Tone Marks

Tone marks preserve the case of the target vowel:

| Input | Output | Rule |
|-------|--------|------|
| `as`  | á      | Lowercase 'a' → lowercase result |
| `As`  | Á      | Uppercase 'A' → uppercase result |
| `AS`  | Á      | Case from vowel, not tone key |

---

## 8. Implementation Notes

This section is descriptive and may lag behind refactors. When in doubt, treat the **behavioral rules** above as normative and consult the **Code Map** at the top of this document for the current implementation.

### 8.1 Key Data Structures

```rust
// Maps: base vowel -> tone key -> toned vowel
static VOWEL_TO_TONED: Lazy<HashMap<char, HashMap<char, char>>>;

// Reverse lookup: toned vowel -> (base vowel, tone key)
static TONED_TO_BASE: Lazy<HashMap<char, (char, char)>>;

// Vowel transform mappings: key -> [(from, to)] pairs
static VOWEL_TRANSFORMS: Lazy<HashMap<char, Vec<(char, char)>>>;

// Reverse for escapes: transformed -> (key, original)
static VOWEL_UNTRANSFORMS: Lazy<HashMap<char, (char, char)>>;

// Sets of vowel categories and delimiters
static NUCLEUS_ONLY_VOWELS: Lazy<HashSet<char>>;
static VOWELS: Lazy<HashSet<char>>;
static WORD_BOUNDARY_CHARS: Lazy<HashSet<char>>;
static TONE_KEYS: Lazy<HashSet<char>>;
```

### 8.1.1 Key Helper Methods

```rust
// Finds the last vowel that can be transformed by a key (used for 'w')
fn find_last_transformable_vowel(&self, key: char, before: usize) -> Option<(usize, (char, char))>

// Finds the last vowel that can be escaped by a transform key
fn find_last_untransformable_vowel(&self, key_lower: char, before: usize) -> Option<(usize, char)>

// Finds matching vowel for free transform (aa/ee/oo non-adjacent, max 4 chars back)
fn find_last_matching_vowel_index(&self, key: char, before: usize, max_distance: usize) -> Option<usize>

// Finds matching 'd' for free transform (d...d non-adjacent, max 4 chars back)
fn find_last_matching_d_index(&self, end_index: usize, max_distance: usize) -> Option<usize>

// Finds target vowel for tone placement using Vietnamese rules
fn find_target_vowel_index(&self, before: usize) -> Option<usize>

// Gets base vowel (strips tone if present)
fn get_base_vowel(&self, ch: char) -> char

// Repositions tone mark when new vowel added (auto fix tone)
fn reposition_tone_if_needed(&mut self, suppressed_last_char: bool, min_start_offset: Option<usize>) -> Option<KeyTransformAction>
```

### 8.1.2 Settings

```rust
// Auto Fix Tone: automatically reposition tone marks (and apply related
// vowel-structure normalization) when adding vowels
auto_fix_tone: bool // Default: true

// Free Tone Placement: bypass valid cluster checks when applying tones
free_tone_placement: bool // Default: false

// Tone Placement: controls how tones are positioned in vowel clusters
// 0 = Orthographic (default), 1 = Nucleus-only
tone_placement: TonePlacement
```

The Rust API exposes this as `VitypeEngine::auto_fix_tone` and `VitypeEngine::free_tone_placement`.
The C FFI can toggle them via `vitype_engine_set_auto_fix_tone(engine, enabled)` and
`vitype_engine_set_free_tone_placement(engine, enabled)`.

### 8.2 Processing Order

The `VitypeEngine::process` method follows this order:

1. **Word boundary check** → Commit the current word into a small internal history window, clear the active word buffers, and return `nil`. For `Enter` (`\r`/`\n`), clear the history window too.
2. **Escape sequence check** → Return undo action if matched
3. **Append to buffer**
4. **Consonant transform** → Check for `dd` → `đ`
5. **Vowel transform** → Check for `aa`/`aw`/etc.
6. **Tone mark** → Find target vowel and apply tone
7. **Auto Fix Tone** → Reposition tone / normalize vowel structure if needed (when enabled)
8. **Invalid syllable check** → Revert to raw text and enter foreign mode if needed

Notes:
- The engine keeps a small history (currently **3 words**) so that if the user **backspaces across a word boundary**, the previous word can be restored into the active buffer and tone/diacritic edits can still be applied.
- Pressing `Enter` clears this history window, so boundary-aware backspace restore is disabled across line breaks.

### 8.3 KeyTransformAction

```rust
#[derive(Clone, Debug, PartialEq)]
struct KeyTransformAction {
    delete_count: usize, // Characters to delete (backspaces)
    text: String,        // Replacement text to insert
}
```

The `delete_count` represents how many characters to delete from the **current output** before inserting `text`. This allows replacing multiple characters when the transform affects a vowel that isn't at the end of the word.

**Simple cases** (vowel at end of buffer):
- `dd` → `đ`: `KeyTransformAction { delete_count: 1, text: "đ" }`
- `tas` → `tá`: `KeyTransformAction { delete_count: 1, text: "á" }`
- `aw` → `ă`: `KeyTransformAction { delete_count: 1, text: "ă" }`

**Free transform cases** (characters between/after vowels):
- `thataj` (second `a`): `KeyTransformAction { delete_count: 2, text: "ât" }` — replaces `at` with `ât`
- `thataj` (`j` after transform): `KeyTransformAction { delete_count: 2, text: "ật" }` — replaces `ât` with `ật`

**Tone with trailing consonants**:
- `chans` → `chán`: `KeyTransformAction { delete_count: 2, text: "án" }` — replaces `an` with `án`
- `muoons` → `muốn`: `KeyTransformAction { delete_count: 2, text: "ốn" }` — replaces `ôn` with `ốn`
- `nguwowif` → `người`: `KeyTransformAction { delete_count: 2, text: "ời" }` — replaces `ơi` with `ời`

### 8.4 Buffer Management

- `buffer` accumulates transformed characters within a word; `raw_buffer` tracks original input
- Reset on word boundary characters
- `is_foreign_mode` disables transforms after invalid vowel clusters until a boundary
- `last_transform_key` and `last_w_transform_kind` track recent transforms for escape handling
- After an escape, transforms are suppressed until a word boundary

### 8.5 C FFI Surface

The core is exposed as a C API for host apps:

```c
VitypeEngine *vitype_engine_new(void);
void vitype_engine_free(VitypeEngine *engine);
void vitype_engine_reset(VitypeEngine *engine);
void vitype_engine_delete_last_character(VitypeEngine *engine);
void vitype_engine_set_auto_fix_tone(VitypeEngine *engine, bool enabled);
void vitype_engine_set_free_tone_placement(VitypeEngine *engine, bool enabled);
void vitype_engine_set_input_method(VitypeEngine *engine, int32_t method);
void vitype_engine_set_output_encoding(VitypeEngine *engine, int32_t encoding);
void vitype_engine_set_tone_placement(VitypeEngine *engine, int32_t placement);
VitypeTransformResult vitype_engine_process(VitypeEngine *engine, const char *input_utf8);
void vitype_engine_free_string(char *text);
```

`VitypeTransformResult` returns `has_action`, `delete_count`, and a heap-allocated UTF-8 `text`
string that must be freed with `vitype_engine_free_string`.

---

## 9. Quick Reference

### 9.1 All Transform Keys

| Key | Function |
|-----|----------|
| `d` | (after d) → đ |
| `a` | (after a) → â |
| `e` | (after e) → ê |
| `o` | (after o) → ô |
| `w` | (after a) → ă, (after o) → ơ, (after u) → ư |
| `s` | Apply sắc tone (´) |
| `f` | Apply huyền tone (`) |
| `r` | Apply hỏi tone (hook) |
| `x` | Apply ngã tone (~) |
| `j` | Apply nặng tone (dot) |
| `z` | Remove tone |

### 9.2 Vietnamese Vowel Inventory

| Base | Variants |
|------|----------|
| a    | a, ă, â + 15 toned = 18 |
| e    | e, ê + 10 toned = 12 |
| i    | i + 5 toned = 6 |
| o    | o, ô, ơ + 15 toned = 18 |
| u    | u, ư + 10 toned = 12 |
| y    | y + 5 toned = 6 |

**Total**: 72 vowel characters (× 2 for case = 144)

### 9.3 Common Vietnamese Words - Typing Examples

| Word | Telex Input | Steps |
|------|-------------|-------|
| việt | `vieejt` | v→i→e→ê→ệ→t |
| nam | `nam` | n→a→m |
| năm | `nawm` | n→a→ă→m |
| đẹp | `ddejp` | d→đ→e→ẹ→p |
| đi | `did` | d→i→**đi** (free transform for dd) |
| người | `nguwowif` | n→g→u→**ư**→o→**ơ**→i→**ờ** |
| nước | `nuwowsc` | n→u→**ư**→o→**ơ**→**ớ**→c |
| được | `dduwowjc` | d→**đ**→u→**ư**→o→**ơ**→**ợ**→c |
| tiếng | `tieengs` | t→i→e→**ê**→n→g→**ế** |
| quốc | `quoocs` | q→u→o→**ô**→c→**ố** |
| học | `hojc` | h→o→**ọ**→c |
| thật | `thataj` | t→h→a→t→**â**→**ậ** (free transform) |
| chán | `chans` | c→h→a→n→**á**→n (tone with trailing) |
| quá | `quas` | q→u→a→**á** (qu cluster, tone on a) |
| huỳnh | `huynhf` | h→u→y→n→h→**ỳ** (uy + consonant, tone on y) |
| uýt | `uyts` | u→y→t→**ý** (uy + consonant, tone on y) |
| úy | `uys` | u→y→**ú** (uy alone, tone on u) |
| gì | `gif` | g→i→**ì** (gi alone, tone on i) |
| giá | `gias` | g→i→a→**á** (gi + vowel, tone on a) |
| giữ | `giuws` | g→i→u→**ư**→**ữ** (gi + ư, tone on ư) |
