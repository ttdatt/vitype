// WTransformTests.swift
// vnkeyTests
//
// Created by Tran Dat on 24/12/25.

#![allow(non_snake_case)]

use super::apply_vni_input;

// MARK: - OIW/UIW Transform Tests
mod oiw_uiw_transform_tests {
    use super::apply_vni_input;

    #[test]
    fn testParagraphTyping() {
        let input = "ho6m nay that65 la2 chan1 qua1 d9i d9i";
        let expected = "hôm nay thật là chán quá đi đi";

        assert_eq!(apply_vni_input(input), expected);
    }

    // MARK: - OIW Transform Tests (ơi)
    // Bug: w should skip 'i' (not w-transformable) and transform 'o' → 'ơ'

    #[test]
    fn testOIW() {
        // "oiw" → "ơi" (w skips i, transforms o → ơ)
        assert_eq!(apply_vni_input("hoi7"), "hơi");
    }

    #[test]
    fn testOIWWithToneAfterW() {
        // "moiwf" → "mời" (w transforms o→ơ, then f applies tone to ơ)
        assert_eq!(apply_vni_input("moi72"), "mời");
    }

    #[test]
    fn testOIWWithToneBeforeW() {
        // "moifw" → "mời" (f applies tone to ò, then w transforms ò→ờ)
        assert_eq!(apply_vni_input("moi27"), "mời");
    }

    #[test]
    fn testOIWEscape() {
        // "hoiww" → "hoiw" (escape the ơi transform)
        assert_eq!(apply_vni_input("hoi77"), "hoi7");
    }

    // MARK: - UIW Transform Tests (ưi)
    // Bug: w should skip 'i' (not w-transformable) and transform 'u' → 'ư'

    #[test]
    fn testUIW() {
        // "uiw" → "ưi" (w skips i, transforms u → ư)
        assert_eq!(apply_vni_input("hui7"), "hưi");
    }

    #[test]
    fn testUIWWithToneAfterW() {
        // "chuiwr" → "chửi" (w transforms u→ư, then r applies tone to ư)
        assert_eq!(apply_vni_input("chui73"), "chửi");
    }

    #[test]
    fn testUIWWithToneBeforeW() {
        // "chuwir" → "chửi" (w transforms u→ư, i appended, r applies tone to ư)
        assert_eq!(apply_vni_input("chu7i3"), "chửi");
    }

    #[test]
    fn testUIWEscape() {
        // "huiww" → "huiw" (escape the ưi transform)
        assert_eq!(apply_vni_input("hui77"), "hui7");
    }
}

// MARK: - UOI7 Transform Tests (ươi)
// Bug: 7 should skip 'i' and still apply the uo → ươ compound transform.
mod uoi7_transform_tests {
    use super::apply_vni_input;

    #[test]
    fn testUOI7() {
        // "uoi7" → "ươi"
        assert_eq!(apply_vni_input("nguoi7"), "ngươi");
    }

    #[test]
    fn testUOI7WithLeading7() {
        assert_eq!(apply_vni_input("ngu7oi"), "ngưoi");
        assert_eq!(apply_vni_input("ngu7oi7"), "ngươi");
    }

    #[test]
    fn testUOI7WithToneAfter7() {
        // "nguoi72" → "người"
        assert_eq!(apply_vni_input("nguoi72"), "người");
    }

    #[test]
    fn testUOI7WithToneBefore7() {
        // "nguoi27" → "người"
        assert_eq!(apply_vni_input("nguoi27"), "người");
    }

    #[test]
    fn testUOI7WithToneOnLeading7() {
        assert_eq!(apply_vni_input("ngu72oi7"), "người");
    }

    #[test]
    fn testUOI7Escape() {
        // "nguoi77" → "nguoi7" (escape the ươi transform)
        assert_eq!(apply_vni_input("nguoi77"), "nguoi7");
    }
}

// MARK: - UAW Compound Transform Tests (ưa)
mod uaw_compound_transform_tests {
    use super::apply_vni_input;

    // MARK: - Basic UAW Tests

    #[test]
    fn testUAW() {
        // "uaw" → "ưa" (compound transform, similar to uow → ươ)
        let result = apply_vni_input("ua7");
        assert_eq!(result, "ưa");
    }

    #[test]
    fn testUWA() {
        // "uwa" → "ưa" (uw → ư, then a appended)
        let result = apply_vni_input("u7a");
        assert_eq!(result, "ưa");
    }

    #[test]
    fn testUAWUppercase() {
        // "UAW" → "ƯA"
        let result = apply_vni_input("UA7");
        assert_eq!(result, "ƯA");
    }

    #[test]
    fn testUWAUppercase() {
        // "UWA" → "ƯA"
        let result = apply_vni_input("U7A");
        assert_eq!(result, "ƯA");
    }

    #[test]
    fn testUAWMixedCase() {
        // "Uaw" → "Ưa"
        let result = apply_vni_input("Ua7");
        assert_eq!(result, "Ưa");
    }

    #[test]
    fn testUWAMixedCase() {
        // "Uwa" → "Ưa"
        let result = apply_vni_input("U7a");
        assert_eq!(result, "Ưa");
    }

    #[test]
    fn testUAWAfterConsonant() {
        // "tuaw" → "tưa"
        let result = apply_vni_input("tua7");
        assert_eq!(result, "tưa");
    }

    #[test]
    fn testUWAAfterConsonant() {
        // "tuwa" → "tưa"
        let result = apply_vni_input("tu7a");
        assert_eq!(result, "tưa");
    }

    #[test]
    fn testUAWAfterMultipleConsonants() {
        // "nguaw" → "ngưa"
        let result = apply_vni_input("ngua7");
        assert_eq!(result, "ngưa");
    }

    #[test]
    fn testUWAAfterMultipleConsonants() {
        // "nguwa" → "ngưa"
        let result = apply_vni_input("ngu7a");
        assert_eq!(result, "ngưa");
    }

    // MARK: - UAW Escape Tests

    #[test]
    fn testUWAWEscape() {
        // "uwaw" → "uaw" (escape compound transform)
        let result = apply_vni_input("ua77");
        assert_eq!(result, "ua7");
    }

    #[test]
    fn testUWAWEscapeUppercase() {
        // "UWAW" → "UAW"
        let result = apply_vni_input("UA77");
        assert_eq!(result, "UA7");
    }

    #[test]
    fn testUWAWEscapeAfterConsonant() {
        // "tuwaw" → "tuaw"
        let result = apply_vni_input("tua77");
        assert_eq!(result, "tua7");
    }

    // MARK: - UAW with Tones

    #[test]
    fn testUAWWithToneSac() {
        // "uaws" → "ứa" (ư is nucleus-only, takes tone)
        let result = apply_vni_input("ua71");
        assert_eq!(result, "ứa");
    }

    #[test]
    fn testUWAWithToneSac() {
        // "uwas" → "ứa"
        let result = apply_vni_input("u7a1");
        assert_eq!(result, "ứa");
    }

    #[test]
    fn testUAWWithAllTones() {
        assert_eq!(apply_vni_input("ua71"), "ứa"); // sắc
        assert_eq!(apply_vni_input("ua72"), "ừa"); // huyền
        assert_eq!(apply_vni_input("ua73"), "ửa"); // hỏi
        assert_eq!(apply_vni_input("ua74"), "ữa"); // ngã
        assert_eq!(apply_vni_input("ua75"), "ựa"); // nặng
    }

    #[test]
    fn testUWAWithAllTones() {
        assert_eq!(apply_vni_input("u7a1"), "ứa"); // sắc
        assert_eq!(apply_vni_input("u7a2"), "ừa"); // huyền
        assert_eq!(apply_vni_input("u7a3"), "ửa"); // hỏi
        assert_eq!(apply_vni_input("u7a4"), "ữa"); // ngã
        assert_eq!(apply_vni_input("u7a5"), "ựa"); // nặng
    }

    #[test]
    fn testUAWAfterConsonantWithTone() {
        // "tuaws" → "tứa"
        let result = apply_vni_input("tua71");
        assert_eq!(result, "tứa");
    }

    #[test]
    fn testUWAAfterConsonantWithTone() {
        // "tuwas" → "tứa"
        let result = apply_vni_input("tu7a1");
        assert_eq!(result, "tứa");
    }

    // MARK: - Real Vietnamese Words with ƯA

    #[test]
    fn testWordMua() {
        // "mưa" (rain) = m + ư + a
        // Using uaw: "muaw" → "mưa"
        let result = apply_vni_input("mua7");
        assert_eq!(result, "mưa");

        assert_eq!(apply_vni_input("mu7a"), "mưa");
    }

    #[test]
    fn testWordMuaWithTone() {
        // "mứa" = mưa with sắc tone
        assert_eq!(apply_vni_input("mua71"), "mứa");
        assert_eq!(apply_vni_input("mu7a1"), "mứa");
    }

    #[test]
    fn testWordChua() {
        // "chưa" (not yet) = ch + ư + a
        let result = apply_vni_input("chua7");
        assert_eq!(result, "chưa");
        assert_eq!(apply_vni_input("chu7a"), "chưa");
    }

    #[test]
    fn testWordChuaWithTone() {
        // "chừa" = chưa with huyền tone
        assert_eq!(apply_vni_input("chua72"), "chừa");
        assert_eq!(apply_vni_input("chu7a2"), "chừa");
    }

    #[test]
    fn testWordXua() {
        // "xưa" (ancient/old) = x + ư + a
        let result = apply_vni_input("xua7");
        assert_eq!(result, "xưa");
    }

    #[test]
    fn testWordXuaAlternative() {
        // "xưa" using uwa path
        let result = apply_vni_input("xu7a");
        assert_eq!(result, "xưa");
    }

    #[test]
    fn testWordLua() {
        // "lửa" (fire) = l + ử + a
        assert_eq!(apply_vni_input("lua73"), "lửa");
        assert_eq!(apply_vni_input("lu7a3"), "lửa");
    }

    #[test]
    fn testWordDua() {
        // "đưa" (to give/bring) = đ + ư + a
        assert_eq!(apply_vni_input("d9ua7"), "đưa");
        assert_eq!(apply_vni_input("d9u7a"), "đưa");
    }

    #[test]
    fn testWordDuaWithTone() {
        // "đừa" with huyền tone
        assert_eq!(apply_vni_input("d9ua72"), "đừa");
        assert_eq!(apply_vni_input("d9u7a2"), "đừa");
    }

    // MARK: - QU Cluster Interaction

    #[test]
    fn testQUAWNotCompound() {
        // "qu" is a consonant cluster, so uaw compound shouldn't apply
        // "quaw" should behave like q + u(consonant part) + aw → ă
        let result = apply_vni_input("qua8");
        assert_eq!(result, "quă");
    }
}

// MARK: - Standalone W Transform Tests
mod standalone_w_transform_tests {
    use super::apply_vni_input;

    // MARK: - Basic Standalone W Tests

    #[test]
    fn testStandaloneWAtStart() {
        // "w" at start of word → "ư"
        let result = apply_vni_input("u7");
        assert_eq!(result, "ư");
    }

    #[test]
    fn testStandaloneWUppercase() {
        // "W" → "Ư"
        let result = apply_vni_input("U7");
        assert_eq!(result, "Ư");
    }

    #[test]
    fn testWAfterConsonant() {
        // "tw" → "tư" (w after consonant becomes ư)
        let result = apply_vni_input("tu7");
        assert_eq!(result, "tư");
    }

    #[test]
    fn testWAfterMultipleConsonants() {
        // "trw" → "trư"
        let result = apply_vni_input("tru7");
        assert_eq!(result, "trư");
    }

    #[test]
    fn testWAfterConsonantUppercase() {
        // "TW" → "TƯ"
        let result = apply_vni_input("TU7");
        assert_eq!(result, "TƯ");
    }

    #[test]
    fn testWAfterConsonantMixedCase() {
        // "Tw" → "Tư"
        let result = apply_vni_input("Tu7");
        assert_eq!(result, "Tư");
    }

    // MARK: - Standalone W Escape Tests

    #[test]
    fn testStandaloneWEscape() {
        // "ww" → "w" (escape standalone w)
        let result = apply_vni_input("u77");
        assert_eq!(result, "u7");
    }

    #[test]
    fn testStandaloneWEscapeUppercase() {
        // "WW" → "W"
        let result = apply_vni_input("U77");
        assert_eq!(result, "U7");
    }

    #[test]
    fn testStandaloneWEscapeAfterConsonant() {
        // "tww" → "tw" (escape w after consonant)
        let result = apply_vni_input("tu77");
        assert_eq!(result, "tu7");
    }

    // MARK: - Standalone W vs UW distinction

    #[test]
    fn testUWStillWorks() {
        // "uw" → "ư" (existing behavior unchanged)
        let result = apply_vni_input("u7");
        assert_eq!(result, "ư");
    }

    #[test]
    fn testUWEscapeStillWorks() {
        // "uww" → "uw" (existing escape behavior unchanged)
        let result = apply_vni_input("u77");
        assert_eq!(result, "u7");
    }

    // MARK: - Standalone W with Tones

    #[test]
    fn testStandaloneWWithTone() {
        // "ws" → "ứ" (standalone w, then tone)
        let result = apply_vni_input("u71");
        assert_eq!(result, "ứ");
    }

    #[test]
    fn testStandaloneWWithAllTones() {
        assert_eq!(apply_vni_input("u71"), "ứ"); // sắc
        assert_eq!(apply_vni_input("u72"), "ừ"); // huyền
        assert_eq!(apply_vni_input("u73"), "ử"); // hỏi
        assert_eq!(apply_vni_input("u74"), "ữ"); // ngã
        assert_eq!(apply_vni_input("u75"), "ự"); // nặng
    }

    #[test]
    fn testWAfterConsonantWithTone() {
        // "tws" → "tứ"
        let result = apply_vni_input("tu71");
        assert_eq!(result, "tứ");
    }

    // MARK: - Real Vietnamese Words with Standalone W

    #[test]
    fn testWordTu() {
        // "tw" → "tư" (the word "tư" meaning "four" or "private")
        let result = apply_vni_input("tu7");
        assert_eq!(result, "tư");
    }

    #[test]
    fn testWordTuWithTone() {
        // "twf" → "từ" (the word "từ" meaning "from" or "word")
        let result = apply_vni_input("tu72");
        assert_eq!(result, "từ");
    }
}

// MARK: - Compound UOW Transform Tests
mod compound_uow_transform_tests {
    use super::apply_vni_input;

    // MARK: - Basic UOW Tests

    #[test]
    fn testUOW() {
        // "uow" → "ươ" (compound transform)
        let result = apply_vni_input("uo7");
        assert_eq!(result, "ươ");
    }

    #[test]
    fn testUOWUppercase() {
        // "UOW" → "ƯƠ"
        let result = apply_vni_input("UO7");
        assert_eq!(result, "ƯƠ");
    }

    #[test]
    fn testUOWMixedCase() {
        // "Uow" → "Ươ"
        let result = apply_vni_input("Uo7");
        assert_eq!(result, "Ươ");
    }

    #[test]
    fn testUOWAfterConsonant() {
        // "tuow" → "tươ"
        let result = apply_vni_input("tuo7");
        assert_eq!(result, "tươ");
    }

    #[test]
    fn testUOWAfterMultipleConsonants() {
        // "nguow" → "ngươ"
        let result = apply_vni_input("nguo7");
        assert_eq!(result, "ngươ");
    }

    // MARK: - UOW Escape Tests

    #[test]
    fn testUOWEscape() {
        // "uoww" → "uow" (escape compound transform)
        let result = apply_vni_input("uo77");
        assert_eq!(result, "uo7");
    }

    #[test]
    fn testUOWEscapeUppercase() {
        // "UOWW" → "UOW"
        let result = apply_vni_input("UO77");
        assert_eq!(result, "UO7");
    }

    #[test]
    fn testUOWEscapeAfterConsonant() {
        // "tuoww" → "tuow"
        let result = apply_vni_input("tuo77");
        assert_eq!(result, "tuo7");
    }

    // MARK: - UOW with Tones

    #[test]
    fn testUOWWithTone() {
        // "uows" → "ướ" (ơ is nucleus-only, takes tone)
        let result = apply_vni_input("uo71");
        assert_eq!(result, "ướ");
    }

    #[test]
    fn testUOWWithAllTones() {
        assert_eq!(apply_vni_input("uo71"), "ướ"); // sắc
        assert_eq!(apply_vni_input("uo72"), "ườ"); // huyền
        assert_eq!(apply_vni_input("uo73"), "ưở"); // hỏi
        assert_eq!(apply_vni_input("uo74"), "ưỡ"); // ngã
        assert_eq!(apply_vni_input("uo75"), "ượ"); // nặng
    }

    #[test]
    fn testUOWAfterConsonantWithTone() {
        // "tuows" → "tướ"
        let result = apply_vni_input("tuo71");
        assert_eq!(result, "tướ");
    }

    // MARK: - UWOW Still Works (Existing Path)

    #[test]
    fn testUWOWStillWorks() {
        // "uwow" → "ươ" (uw→ư, then ow→ơ)
        let result = apply_vni_input("u7o7");
        assert_eq!(result, "ươ");
    }

    #[test]
    fn testUWOWAfterConsonant() {
        // "tuwow" → "tươ"
        let result = apply_vni_input("tu7o7");
        assert_eq!(result, "tươ");
    }

    // MARK: - UOW with Pre-Typed Tones

    #[test]
    fn testUOSThenW() {
        // "u1o" → "úo" (tone on u, 2 vowels → 1st), then "7" compounds uo → ươ and
        // preserves the tone on ơ.
        let result = apply_vni_input("u1o7");
        assert_eq!(result, "ướ");
    }

    #[test]
    fn testTonedUOCompound() {
        // "u2o" → "ùo", then "7" compounds uo → ươ and preserves the tone on ơ.
        let result = apply_vni_input("u2o7");
        assert_eq!(result, "ườ");
    }

    #[test]
    fn testMuonToneOverrideAfterW() {
        // "muwjowjn" → "mượn" (tone applied early, then re-applied after ow)
        assert_eq!(apply_vni_input("mu75on"), "mượn");
        // "mwjonwj" → "mượn" (w as ư, tone applied early, then re-applied)
        assert_eq!(apply_vni_input("mu7on5"), "mượn");
        // "mwjon" → "mượn" (auto-fix ưo + consonant → ươ + consonant)
        assert_eq!(apply_vni_input("mu7o5n"), "mượn");
    }

    // MARK: - Standalone ơ + Vowel Auto-Fix

    #[test]
    fn testStandaloneOhornBeforeVowelRemovesHorn() {
        // "ho7a" -> "hoa" (standalone ơ before vowel auto-fixes back to o)
        assert_eq!(apply_vni_input("ho7a"), "hoa");
    }

    #[test]
    fn testStandaloneOhornBeforeVowelWithBreveAndTone() {
        // Regression: "ho7a85c" should become "hoặc", not "hơặc".
        assert_eq!(apply_vni_input("ho7a85c"), "hoặc");
    }

    #[test]
    fn testStandaloneOhornKeepsOiCluster() {
        // "ơi" is valid and must keep horn on o.
        assert_eq!(apply_vni_input("ho7i"), "hơi");
    }

    #[test]
    fn testStandaloneOhornDoesNotBreakUowCompound() {
        // ươ-cluster remains intact because ơ is preceded by ư.
        assert_eq!(apply_vni_input("hu7o7u"), "hươu");
    }

    #[test]
    fn testQUClusterNoCompound() {
        // "qu" is a consonant cluster, so uow compound shouldn't turn it into "qươ"
        // "quow" should behave like plain ow → ơ
        let result = apply_vni_input("quo7");
        assert_eq!(result, "quơ");
    }

    // MARK: - Real Vietnamese Words with UOW

    #[test]
    fn testWordMuon() {
        // "muown" → "mươn" (not a real word, but tests the pattern)
        let result = apply_vni_input("muo7n");
        assert_eq!(result, "mươn");
    }

    #[test]
    fn testWordDuoc() {
        // "dduowc" → "đươc"
        let result = apply_vni_input("d9uo7c");
        assert_eq!(result, "đươc");
    }

    #[test]
    fn testWordDuocWithTone() {
        // "dduowjc" → "được" (with nặng tone)
        let result = apply_vni_input("d9uo75c");
        assert_eq!(result, "được");
    }

    #[test]
    fn testWordDuocToneBefore7() {
        // Regression: tone typed before 7 should still produce "ươ" and preserve tone.
        assert_eq!(apply_vni_input("duoc57"), "dược");
        assert_eq!(apply_vni_input("d9uoc57"), "được");
        assert_eq!(apply_vni_input("uoc57"), "ược");
    }

    #[test]
    fn testWordHufowToneBefore7() {
        // Regression: tone typed before 7 should still land on ơ.
        assert_eq!(apply_vni_input("hu2o7"), "hườ");
        assert_eq!(apply_vni_input("hu2o7u"), "hườu");
    }

    // MARK: - UOCW Pattern Tests (similar to UOUW)

    #[test]
    fn testUOCW() {
        // uocw pattern: type "uoc" first, then "w" transforms uo → ươ
        let result = apply_vni_input("uoc7");
        assert_eq!(result, "ươc");

        let r1 = apply_vni_input("uoc75");
        assert_eq!(r1, "ược"); // nặng on ơ → ợ

        let r2 = apply_vni_input("uoc71");
        assert_eq!(r2, "ước"); // sắc on ơ → ớ

        let r3 = apply_vni_input("uoc72");
        assert_eq!(r3, "ườc"); // huyền on ơ → ờ

        let r4 = apply_vni_input("uoc73");
        assert_eq!(r4, "ưởc"); // hỏi on ơ → ở

        let r5 = apply_vni_input("uoc74");
        assert_eq!(r5, "ưỡc"); // ngã on ơ → ỡ
    }

    #[test]
    fn testWordDuocWithUOCW() {
        // uocw pattern with consonant prefix
        let result = apply_vni_input("d9uoc7");
        assert_eq!(result, "đươc");

        let r1 = apply_vni_input("d9uoc75");
        assert_eq!(r1, "được"); // nặng on ơ → ợ

        let r2 = apply_vni_input("d9uoc71");
        assert_eq!(r2, "đước"); // sắc on ơ → ớ

        let r3 = apply_vni_input("d9uoc72");
        assert_eq!(r3, "đườc"); // huyền on ơ → ờ

        let r4 = apply_vni_input("d9uoc73");
        assert_eq!(r4, "đưởc"); // hỏi on ơ → ở

        let r5 = apply_vni_input("d9uoc74");
        assert_eq!(r5, "đưỡc"); // ngã on ơ → ỡ

        assert_eq!(apply_vni_input("d9uop75"), "đượp");
    }

    #[test]
    fn testWordNguoi() {
        // Alternative: "nguowif" → "người" using uow compound
        let result = apply_vni_input("nguo7i2");
        assert_eq!(result, "người");
    }

    #[test]
    fn testWordNguoiExisting() {
        // Existing path: "nguwowif" → "người"
        let result = apply_vni_input("ngu7o7i2");
        assert_eq!(result, "người");
    }

    #[test]
    fn testWordNuoc() {
        // "nuowsc" → "nước" using uow compound
        let result = apply_vni_input("nuo71c");
        assert_eq!(result, "nước");
    }

    #[test]
    fn testWordNuocExisting() {
        // Existing path: "nuwowsc" → "nước"
        let result = apply_vni_input("nu7o71c");
        assert_eq!(result, "nước");
    }

    #[test]
    fn testWordTuoi2() {
        // "tươi" (fresh) = t + ư + ơ + i
        // "tuowi" → "tươi"
        let result = apply_vni_input("tuo7i");
        assert_eq!(result, "tươi");
    }

    #[test]
    fn testWordTuoiWithTone() {
        // "tươi" with sắc tone → "tưới" (to water)
        // "tuowis" → tone goes on ơ (nucleus-only)
        let result = apply_vni_input("tuo7i1");
        assert_eq!(result, "tưới");
    }

    #[test]
    fn testWordHuuWithTone() {
        let result = apply_vni_input("hu7u");
        assert_eq!(result, "hưu");

        let r1 = apply_vni_input("huu7");
        assert_eq!(r1, "hưu");

        let r2 = apply_vni_input("huu75");
        assert_eq!(r2, "hựu");

        let r3 = apply_vni_input("huu71");
        assert_eq!(r3, "hứu");

        let r4 = apply_vni_input("huu72");
        assert_eq!(r4, "hừu");

        let r5 = apply_vni_input("huu73");
        assert_eq!(r5, "hửu");

        let r6 = apply_vni_input("huu74");
        assert_eq!(r6, "hữu");
    }

    #[test]
    fn testWordHuouWithTone() {
        let result = apply_vni_input("huou7");
        assert_eq!(result, "hươu");

        // Regression: pre-horned u (via u7) must still form "hươu".
        assert_eq!(apply_vni_input("hu7ou7"), "hươu");

        // Regression: tone typed before the compound "7" still lands on "ơ".
        assert_eq!(apply_vni_input("huo1u7"), "hướu");
        assert_eq!(apply_vni_input("hu71ou7"), "hướu");

        let r1 = apply_vni_input("hou7u");
        assert_eq!(r1, "hươu");

        let r2 = apply_vni_input("hou7u5");
        assert_eq!(r2, "hượu");

        let r3 = apply_vni_input("hou7u1");
        assert_eq!(r3, "hướu");

        let r4 = apply_vni_input("hou7u2");
        assert_eq!(r4, "hườu");

        let r5 = apply_vni_input("hou7u3");
        assert_eq!(r5, "hưởu");

        let r6 = apply_vni_input("hou7u4");
        assert_eq!(r6, "hưỡu");
    }
}
