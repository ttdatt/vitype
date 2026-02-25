// WTransformTests.swift
// vnkeyTests
//
// Created by Tran Dat on 24/12/25.

#![allow(non_snake_case)]

use super::test_helpers::apply_input;

// MARK: - OIW/UIW Transform Tests
mod oiw_uiw_transform_tests {
    use super::apply_input;

    #[test]
    fn testParagraphTyping() {
        let input = "hoom nay thataj laf chans quas ddi did";
        let expected = "hôm nay thật là chán quá đi đi";

        assert_eq!(apply_input(input), expected);
    }

    // MARK: - OIW Transform Tests (ơi)
    // Bug: w should skip 'i' (not w-transformable) and transform 'o' → 'ơ'

    #[test]
    fn testOIW() {
        // "oiw" → "ơi" (w skips i, transforms o → ơ)
        assert_eq!(apply_input("hoiw"), "hơi");
    }

    #[test]
    fn testOIWWithToneAfterW() {
        // "moiwf" → "mời" (w transforms o→ơ, then f applies tone to ơ)
        assert_eq!(apply_input("moiwf"), "mời");
    }

    #[test]
    fn testOIWWithToneBeforeW() {
        // "moifw" → "mời" (f applies tone to ò, then w transforms ò→ờ)
        assert_eq!(apply_input("moifw"), "mời");
    }

    #[test]
    fn testOIWEscape() {
        // "hoiww" → "hoiw" (escape the ơi transform)
        assert_eq!(apply_input("hoiww"), "hoiw");
    }

    // MARK: - UIW Transform Tests (ưi)
    // Bug: w should skip 'i' (not w-transformable) and transform 'u' → 'ư'

    #[test]
    fn testUIW() {
        // "uiw" → "ưi" (w skips i, transforms u → ư)
        assert_eq!(apply_input("huiw"), "hưi");
    }

    #[test]
    fn testUIWWithToneAfterW() {
        // "chuiwr" → "chửi" (w transforms u→ư, then r applies tone to ư)
        assert_eq!(apply_input("chuiwr"), "chửi");
    }

    #[test]
    fn testUIWWithToneBeforeW() {
        // "chuwir" → "chửi" (w transforms u→ư, i appended, r applies tone to ư)
        assert_eq!(apply_input("chuwir"), "chửi");
    }

    #[test]
    fn testUIWEscape() {
        // "huiww" → "huiw" (escape the ưi transform)
        assert_eq!(apply_input("huiww"), "huiw");
    }
}

// MARK: - UOIW Transform Tests (ươi)
// Bug: w should skip 'i' and still apply the uo → ươ compound transform.
mod uoiw_transform_tests {
    use super::apply_input;

    #[test]
    fn testUOIW() {
        // "uoiw" → "ươi"
        assert_eq!(apply_input("nguoiw"), "ngươi");
        assert_eq!(apply_input("ngwoiw"), "ngươi");
        assert_eq!(apply_input("nguwoiw"), "ngươi");
    }

    #[test]
    fn testUOIWWithLeadingW() {
        assert_eq!(apply_input("ngwoi"), "ngưoi");
        assert_eq!(apply_input("nguwoi"), "ngưoi");
    }

    #[test]
    fn testUOIWWithToneAfterW() {
        // "nguoiwf" → "người"
        assert_eq!(apply_input("nguoiwf"), "người");
    }

    #[test]
    fn testUOIWWithToneBeforeW() {
        // "nguoifw" → "người"
        assert_eq!(apply_input("nguoifw"), "người");
    }

    #[test]
    fn testUOIWWithToneOnLeadingW() {
        assert_eq!(apply_input("ngwfoiw"), "người");
        assert_eq!(apply_input("nguwfoiw"), "người");
    }

    #[test]
    fn testUOIWEscape() {
        // "nguoiww" → "nguoiw" (escape the ươi transform)
        assert_eq!(apply_input("nguoiww"), "nguoiw");
    }
}

// MARK: - UAW Compound Transform Tests (ưa)
mod uaw_compound_transform_tests {
    use super::apply_input;

    // MARK: - Basic UAW Tests

    #[test]
    fn testUAW() {
        // "uaw" → "ưa" (compound transform, similar to uow → ươ)
        let result = apply_input("uaw");
        assert_eq!(result, "ưa");
    }

    #[test]
    fn testUWA() {
        // "uwa" → "ưa" (uw → ư, then a appended)
        let result = apply_input("uwa");
        assert_eq!(result, "ưa");
    }

    #[test]
    fn testUAWUppercase() {
        // "UAW" → "ƯA"
        let result = apply_input("UAW");
        assert_eq!(result, "ƯA");
    }

    #[test]
    fn testUWAUppercase() {
        // "UWA" → "ƯA"
        let result = apply_input("UWA");
        assert_eq!(result, "ƯA");
    }

    #[test]
    fn testUAWMixedCase() {
        // "Uaw" → "Ưa"
        let result = apply_input("Uaw");
        assert_eq!(result, "Ưa");
    }

    #[test]
    fn testUWAMixedCase() {
        // "Uwa" → "Ưa"
        let result = apply_input("Uwa");
        assert_eq!(result, "Ưa");
    }

    #[test]
    fn testUAWAfterConsonant() {
        // "tuaw" → "tưa"
        let result = apply_input("tuaw");
        assert_eq!(result, "tưa");
    }

    #[test]
    fn testUWAAfterConsonant() {
        // "tuwa" → "tưa"
        let result = apply_input("tuwa");
        assert_eq!(result, "tưa");
    }

    #[test]
    fn testUAWAfterMultipleConsonants() {
        // "nguaw" → "ngưa"
        let result = apply_input("nguaw");
        assert_eq!(result, "ngưa");
    }

    #[test]
    fn testUWAAfterMultipleConsonants() {
        // "nguwa" → "ngưa"
        let result = apply_input("nguwa");
        assert_eq!(result, "ngưa");
    }

    // MARK: - UAW Escape Tests

    #[test]
    fn testUWAWEscape() {
        // "uwaw" stays literal because final "w" makes the syllable foreign
        let result = apply_input("uwaw");
        assert_eq!(result, "uwaw");
    }

    #[test]
    fn testUWAWEscapeUppercase() {
        // "UWAW" stays literal because final "W" makes the syllable foreign
        let result = apply_input("UWAW");
        assert_eq!(result, "UWAW");
    }

    #[test]
    fn testUWAWEscapeAfterConsonant() {
        // "tuwaw" stays literal because final "w" makes the syllable foreign
        let result = apply_input("tuwaw");
        assert_eq!(result, "tuwaw");
    }

    // MARK: - UAW with Tones

    #[test]
    fn testUAWWithToneSac() {
        // "uaws" → "ứa" (ư is nucleus-only, takes tone)
        let result = apply_input("uaws");
        assert_eq!(result, "ứa");
    }

    #[test]
    fn testUWAWithToneSac() {
        // "uwas" → "ứa"
        let result = apply_input("uwas");
        assert_eq!(result, "ứa");
    }

    #[test]
    fn testUAWWithAllTones() {
        assert_eq!(apply_input("uaws"), "ứa"); // sắc
        assert_eq!(apply_input("uawf"), "ừa"); // huyền
        assert_eq!(apply_input("uawr"), "ửa"); // hỏi
        assert_eq!(apply_input("uawx"), "ữa"); // ngã
        assert_eq!(apply_input("uawj"), "ựa"); // nặng
    }

    #[test]
    fn testUWAWithAllTones() {
        assert_eq!(apply_input("uwas"), "ứa"); // sắc
        assert_eq!(apply_input("uwaf"), "ừa"); // huyền
        assert_eq!(apply_input("uwar"), "ửa"); // hỏi
        assert_eq!(apply_input("uwax"), "ữa"); // ngã
        assert_eq!(apply_input("uwaj"), "ựa"); // nặng
    }

    #[test]
    fn testUAWAfterConsonantWithTone() {
        // "tuaws" → "tứa"
        let result = apply_input("tuaws");
        assert_eq!(result, "tứa");
    }

    #[test]
    fn testUWAAfterConsonantWithTone() {
        // "tuwas" → "tứa"
        let result = apply_input("tuwas");
        assert_eq!(result, "tứa");
    }

    // MARK: - Real Vietnamese Words with ƯA

    #[test]
    fn testWordMua() {
        // "mưa" (rain) = m + ư + a
        // Using uaw: "muaw" → "mưa"
        let result = apply_input("muaw");
        assert_eq!(result, "mưa");

        assert_eq!(apply_input("muwa"), "mưa");
    }

    #[test]
    fn testWordMuaWithTone() {
        // "mứa" = mưa with sắc tone
        assert_eq!(apply_input("muaws"), "mứa");
        assert_eq!(apply_input("muwas"), "mứa");
    }

    #[test]
    fn testWordChua() {
        // "chưa" (not yet) = ch + ư + a
        let result = apply_input("chuaw");
        assert_eq!(result, "chưa");
        assert_eq!(apply_input("chuwa"), "chưa");
    }

    #[test]
    fn testWordChuaWithTone() {
        // "chừa" = chưa with huyền tone
        assert_eq!(apply_input("chuawf"), "chừa");
        assert_eq!(apply_input("chuwaf"), "chừa");
    }

    #[test]
    fn testWordXua() {
        // "xưa" (ancient/old) = x + ư + a
        let result = apply_input("xuaw");
        assert_eq!(result, "xưa");
    }

    #[test]
    fn testWordXuaAlternative() {
        // "xưa" using uwa path
        let result = apply_input("xuwa");
        assert_eq!(result, "xưa");
    }

    #[test]
    fn testWordLua() {
        // "lửa" (fire) = l + ử + a
        assert_eq!(apply_input("luawr"), "lửa");
        assert_eq!(apply_input("luwar"), "lửa");
    }

    #[test]
    fn testWordDua() {
        // "đưa" (to give/bring) = đ + ư + a
        assert_eq!(apply_input("dduaw"), "đưa");
        assert_eq!(apply_input("dduwa"), "đưa");
    }

    #[test]
    fn testWordDuaWithTone() {
        // "đừa" with huyền tone
        assert_eq!(apply_input("dduawf"), "đừa");
        assert_eq!(apply_input("dduwaf"), "đừa");
    }

    // MARK: - QU Cluster Interaction

    #[test]
    fn testQUAWNotCompound() {
        // "qu" is a consonant cluster, so uaw compound shouldn't apply
        // "quaw" should behave like q + u(consonant part) + aw → ă
        let result = apply_input("quaw");
        assert_eq!(result, "quă");
    }
}

// MARK: - Standalone W Transform Tests
mod standalone_w_transform_tests {
    use super::apply_input;

    // MARK: - Basic Standalone W Tests

    #[test]
    fn testStandaloneWAtStart() {
        // "w" at start of word → "ư"
        let result = apply_input("w");
        assert_eq!(result, "ư");
    }

    #[test]
    fn testStandaloneWUppercase() {
        // "W" → "Ư"
        let result = apply_input("W");
        assert_eq!(result, "Ư");
    }

    #[test]
    fn testWAfterConsonant() {
        // "tw" → "tư" (w after consonant becomes ư)
        let result = apply_input("tw");
        assert_eq!(result, "tư");
    }

    #[test]
    fn testWAfterMultipleConsonants() {
        // "trw" → "trư"
        let result = apply_input("trw");
        assert_eq!(result, "trư");
    }

    #[test]
    fn testWAfterConsonantUppercase() {
        // "TW" → "TƯ"
        let result = apply_input("TW");
        assert_eq!(result, "TƯ");
    }

    #[test]
    fn testWAfterConsonantMixedCase() {
        // "Tw" → "Tư"
        let result = apply_input("Tw");
        assert_eq!(result, "Tư");
    }

    // MARK: - Standalone W Escape Tests

    #[test]
    fn testStandaloneWEscape() {
        // "ww" → "w" (escape standalone w)
        let result = apply_input("ww");
        assert_eq!(result, "w");
    }

    #[test]
    fn testStandaloneWEscapeUppercase() {
        // "WW" → "W"
        let result = apply_input("WW");
        assert_eq!(result, "W");
    }

    #[test]
    fn testStandaloneWEscapeAfterConsonant() {
        // "tww" → "tw" (escape w after consonant)
        let result = apply_input("tww");
        assert_eq!(result, "tw");
    }

    // MARK: - Standalone W vs UW distinction

    #[test]
    fn testUWStillWorks() {
        // "uw" → "ư" (existing behavior unchanged)
        let result = apply_input("uw");
        assert_eq!(result, "ư");
    }

    #[test]
    fn testUWEscapeStillWorks() {
        // "uww" → "uw" (existing escape behavior unchanged)
        let result = apply_input("uww");
        assert_eq!(result, "uw");
    }

    // MARK: - Standalone W with Tones

    #[test]
    fn testStandaloneWWithTone() {
        // "ws" → "ứ" (standalone w, then tone)
        let result = apply_input("ws");
        assert_eq!(result, "ứ");
    }

    #[test]
    fn testStandaloneWWithAllTones() {
        assert_eq!(apply_input("ws"), "ứ"); // sắc
        assert_eq!(apply_input("wf"), "ừ"); // huyền
        assert_eq!(apply_input("wr"), "ử"); // hỏi
        assert_eq!(apply_input("wx"), "ữ"); // ngã
        assert_eq!(apply_input("wj"), "ự"); // nặng
    }

    #[test]
    fn testWAfterConsonantWithTone() {
        // "tws" → "tứ"
        let result = apply_input("tws");
        assert_eq!(result, "tứ");
    }

    // MARK: - Real Vietnamese Words with Standalone W

    #[test]
    fn testWordTu() {
        // "tw" → "tư" (the word "tư" meaning "four" or "private")
        let result = apply_input("tw");
        assert_eq!(result, "tư");
    }

    #[test]
    fn testWordTuWithTone() {
        // "twf" → "từ" (the word "từ" meaning "from" or "word")
        let result = apply_input("twf");
        assert_eq!(result, "từ");
    }
}

// MARK: - Compound UOW Transform Tests
mod compound_uow_transform_tests {
    use super::apply_input;

    // MARK: - Basic UOW Tests

    #[test]
    fn testUOW() {
        // "uow" → "ươ" (compound transform)
        let result = apply_input("uow");
        assert_eq!(result, "ươ");
    }

    #[test]
    fn testUOWUppercase() {
        // "UOW" → "ƯƠ"
        let result = apply_input("UOW");
        assert_eq!(result, "ƯƠ");
    }

    #[test]
    fn testUOWMixedCase() {
        // "Uow" → "Ươ"
        let result = apply_input("Uow");
        assert_eq!(result, "Ươ");
    }

    #[test]
    fn testUOWAfterConsonant() {
        // "tuow" → "tươ"
        let result = apply_input("tuow");
        assert_eq!(result, "tươ");
    }

    #[test]
    fn testUOWAfterMultipleConsonants() {
        // "nguow" → "ngươ"
        let result = apply_input("nguow");
        assert_eq!(result, "ngươ");
    }

    // MARK: - UOW Escape Tests

    #[test]
    fn testUOWEscape() {
        // "uoww" → "uow" (escape compound transform)
        let result = apply_input("uoww");
        assert_eq!(result, "uow");
    }

    #[test]
    fn testUOWEscapeUppercase() {
        // "UOWW" → "UOW"
        let result = apply_input("UOWW");
        assert_eq!(result, "UOW");
    }

    #[test]
    fn testUOWEscapeAfterConsonant() {
        // "tuoww" → "tuow"
        let result = apply_input("tuoww");
        assert_eq!(result, "tuow");
    }

    // MARK: - UOW with Tones

    #[test]
    fn testUOWWithTone() {
        // "uows" → "ướ" (ơ is nucleus-only, takes tone)
        let result = apply_input("uows");
        assert_eq!(result, "ướ");
    }

    #[test]
    fn testUOWWithAllTones() {
        assert_eq!(apply_input("uows"), "ướ"); // sắc
        assert_eq!(apply_input("uowf"), "ườ"); // huyền
        assert_eq!(apply_input("uowr"), "ưở"); // hỏi
        assert_eq!(apply_input("uowx"), "ưỡ"); // ngã
        assert_eq!(apply_input("uowj"), "ượ"); // nặng
    }

    #[test]
    fn testUOWAfterConsonantWithTone() {
        // "tuows" → "tướ"
        let result = apply_input("tuows");
        assert_eq!(result, "tướ");
    }

    // MARK: - UWOW Still Works (Existing Path)

    #[test]
    fn testUWOWStillWorks() {
        // "uwow" → "ươ" (uw→ư, then ow→ơ)
        let result = apply_input("uwow");
        assert_eq!(result, "ươ");
    }

    #[test]
    fn testUWOWAfterConsonant() {
        // "tuwow" → "tươ"
        let result = apply_input("tuwow");
        assert_eq!(result, "tươ");
    }

    // MARK: - UOW with Pre-Typed Tones

    #[test]
    fn testUOSThenW() {
        // "uos" → "úo" (tone on u, 2 vowels → 1st), then "w" compounds uo → ươ and
        // preserves the tone on ơ.
        let result = apply_input("uosw");
        assert_eq!(result, "ướ");
    }

    #[test]
    fn testTonedUOCompound() {
        // "uf" → tone on u → "ù", then "o" → "ùo", then "w" compounds uo → ươ
        let result = apply_input("ufow");
        assert_eq!(result, "ườ");
    }

    #[test]
    fn testMuonToneOverrideAfterW() {
        // "muwjowjn" → "mượn" (tone applied early, then re-applied after ow)
        assert_eq!(apply_input("muwjowjn"), "mượn");
        // "mwjonwj" → "mượn" (w as ư, tone applied early, then re-applied)
        assert_eq!(apply_input("mwjonwj"), "mượn");
        // "mwjon" → "mượn" (auto-fix ưo + consonant → ươ + consonant)
        assert_eq!(apply_input("mwjon"), "mượn");
    }

    // MARK: - Standalone ơ + Vowel Auto-Fix

    #[test]
    fn testStandaloneOhornBeforeVowelRemovesHorn() {
        // "howa" -> "hoa" (standalone ơ before vowel auto-fixes back to o)
        assert_eq!(apply_input("howa"), "hoa");
    }

    #[test]
    fn testStandaloneOhornBeforeVowelWithBreveAndTone() {
        // Regression: "howawjc" should become "hoặc", not "hơặc".
        assert_eq!(apply_input("howawjc"), "hoặc");
    }

    #[test]
    fn testStandaloneOhornKeepsOiCluster() {
        // "ơi" is valid and must keep horn on o.
        assert_eq!(apply_input("howi"), "hơi");
    }

    #[test]
    fn testStandaloneOhornDoesNotBreakUowCompound() {
        // ươ-cluster remains intact because ơ is preceded by ư.
        assert_eq!(apply_input("huwouw"), "hươu");
    }

    #[test]
    fn testQUClusterNoCompound() {
        // "qu" is a consonant cluster, so uow compound shouldn't turn it into "qươ"
        // "quow" should behave like plain ow → ơ
        let result = apply_input("quow");
        assert_eq!(result, "quơ");
    }

    // MARK: - Real Vietnamese Words with UOW

    #[test]
    fn testWordMuon() {
        // "muown" → "mươn" (not a real word, but tests the pattern)
        let result = apply_input("muown");
        assert_eq!(result, "mươn");
    }

    #[test]
    fn testWordDuoc() {
        // "dduowc" → "đươc"
        let result = apply_input("dduowc");
        assert_eq!(result, "đươc");
    }

    #[test]
    fn testWordDuocWithTone() {
        // "dduowjc" → "được" (with nặng tone)
        let result = apply_input("dduowjc");
        assert_eq!(result, "được");
    }

    #[test]
    fn testWordHufowToneBeforeW() {
        // Regression: tone typed before w should still land on ơ.
        assert_eq!(apply_input("hufow"), "hườ");
        assert_eq!(apply_input("hufowu"), "hườu");
    }

    #[test]
    fn testWordDuocToneBeforeW() {
        // Regression: tone typed before w should still produce "ươ" and preserve tone.
        assert_eq!(apply_input("duocjw"), "dược");
        assert_eq!(apply_input("dduocjw"), "được");
        assert_eq!(apply_input("uocjw"), "ược");
    }

    // MARK: - UOCW Pattern Tests (similar to UOUW)

    #[test]
    fn testUOCW() {
        // uocw pattern: type "uoc" first, then "w" transforms uo → ươ
        let result = apply_input("uocw");
        assert_eq!(result, "ươc");

        let r1 = apply_input("uocwj");
        assert_eq!(r1, "ược"); // nặng on ơ → ợ

        let r2 = apply_input("uocws");
        assert_eq!(r2, "ước"); // sắc on ơ → ớ

        let r3 = apply_input("uocwf");
        assert_eq!(r3, "ườc"); // huyền on ơ → ờ

        let r4 = apply_input("uocwr");
        assert_eq!(r4, "ưởc"); // hỏi on ơ → ở

        let r5 = apply_input("uocwx");
        assert_eq!(r5, "ưỡc"); // ngã on ơ → ỡ
    }

    #[test]
    fn testWordDuocWithUOCW() {
        // uocw pattern with consonant prefix
        let result = apply_input("dduocw");
        assert_eq!(result, "đươc");

        let r1 = apply_input("dduocwj");
        assert_eq!(r1, "được"); // nặng on ơ → ợ

        let r2 = apply_input("dduocws");
        assert_eq!(r2, "đước"); // sắc on ơ → ớ

        let r3 = apply_input("dduocwf");
        assert_eq!(r3, "đườc"); // huyền on ơ → ờ

        let r4 = apply_input("dduocwr");
        assert_eq!(r4, "đưởc"); // hỏi on ơ → ở

        let r5 = apply_input("dduocwx");
        assert_eq!(r5, "đưỡc"); // ngã on ơ → ỡ

        assert_eq!(apply_input("dduopwj"), "đượp");
    }

    #[test]
    fn testWordNguoi() {
        // Alternative: "nguowif" → "người" using uow compound
        let result = apply_input("nguowif");
        assert_eq!(result, "người");
    }

    #[test]
    fn testWordNguoiExisting() {
        // Existing path: "nguwowif" → "người"
        let result = apply_input("nguwowif");
        assert_eq!(result, "người");
    }

    #[test]
    fn testWordNuoc() {
        // "nuowsc" → "nước" using uow compound
        let result = apply_input("nuowsc");
        assert_eq!(result, "nước");
    }

    #[test]
    fn testWordNuocExisting() {
        // Existing path: "nuwowsc" → "nước"
        let result = apply_input("nuwowsc");
        assert_eq!(result, "nước");
    }

    #[test]
    fn testWordTuoi2() {
        // "tươi" (fresh) = t + ư + ơ + i
        // "tuowi" → "tươi"
        let result = apply_input("tuowi");
        assert_eq!(result, "tươi");
    }

    #[test]
    fn testWordTuoiWithTone() {
        // "tươi" with sắc tone → "tưới" (to water)
        // "tuowis" → tone goes on ơ (nucleus-only)
        let result = apply_input("tuowis");
        assert_eq!(result, "tưới");
    }

    #[test]
    fn testWordHuuWithTone() {
        let result = apply_input("huwu");
        assert_eq!(result, "hưu");

        let r1 = apply_input("huuw");
        assert_eq!(r1, "hưu");

        let r2 = apply_input("huuwj");
        assert_eq!(r2, "hựu");

        let r3 = apply_input("huuws");
        assert_eq!(r3, "hứu");

        let r4 = apply_input("huuwf");
        assert_eq!(r4, "hừu");

        let r5 = apply_input("huuwr");
        assert_eq!(r5, "hửu");

        let r6 = apply_input("huuwx");
        assert_eq!(r6, "hữu");
    }

    #[test]
    fn testWordHuouWithTone() {
        let result = apply_input("huouw");
        assert_eq!(result, "hươu");

        // Regressions: pre-horned u (via standalone w or uw) must still form "hươu".
        assert_eq!(apply_input("hwouw"), "hươu");
        assert_eq!(apply_input("huwouw"), "hươu");

        // Regressions: tone typed before the compound "w" still lands on "ơ".
        assert_eq!(apply_input("huousw"), "hướu");
        assert_eq!(apply_input("huwsouw"), "hướu");

        let r1 = apply_input("houwu");
        assert_eq!(r1, "hươu");

        let r2 = apply_input("houwuj");
        assert_eq!(r2, "hượu");

        let r3 = apply_input("houwus");
        assert_eq!(r3, "hướu");

        let r4 = apply_input("houwuf");
        assert_eq!(r4, "hườu");

        let r5 = apply_input("houwur");
        assert_eq!(r5, "hưởu");

        let r6 = apply_input("houwux");
        assert_eq!(r6, "hưỡu");
    }
}
