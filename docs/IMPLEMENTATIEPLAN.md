# Implementatieplan Stemstroom

Doel: een zelfstandig iPhone-project met lokale, doorlopende transcriptie en veilige opslag.
Architectuur: native SwiftUI-scherm, aparte opname- en herkenningslaag, Foundation-kern voor documenten en opslag.
Techniek: Swift 6-toolchain (Swift 5-taalmodus), iOS 26, AVFAudio en Speech; geen externe runtime-afhankelijkheden.
Specificatie: [ONTWERP.md](ONTWERP.md).

## Taken

- [x] Documentkern en 21 Swift-tests: finale passages, vervangbare voorlopige tekst, markeringen, 3+ uur gesimuleerde tekst, atomaire opslag en herstel. Alle 21 tests slagen op macOS.
- [x] Audio/spraak geïmplementeerd: lokale taalmodellen voorbereiden, begrensde microfoonstream, conversie buiten de hoofdthread, finaliseren bij Stop.
- [x] Sessiecontroller geïmplementeerd: permissies, toestand, autosave, achtergrondaudio, onderbrekingen en hervatten. Niet-opgeslagen tekst blokkeert documentvervanging.
- [x] SwiftUI-scherm geïmplementeerd: Nederlandse taalvarianten, timer, tekst, duidelijke acties, eerdere sessies en foutmeldingen.
- [x] Xcode-project, buildscript en installatiehandleiding; onafhankelijke bronreview uitgevoerd en bevestigde bevindingen verwerkt.
- [x] Structurele controles, kerntests en beide Xcode-builds geslaagd. Resultaten en resterende iPhone-controles staan in VERIFICATIE.md. De duurtest op een echte iPhone blijft open.

Werk alleen binnen deze projectmap. De bestaande Brindero-app en gedeelde Git-index blijven buiten deze taak.
