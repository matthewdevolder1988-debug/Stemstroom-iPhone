# Verificatie — 6 oktober 2026

## Uitgevoerd op Windows

- `node scripts/check-project.mjs`: exit 0; 7 unieke Swift-bronbestanden, alle object- en bestandsverwijzingen geldig. IJking wees eerst 2 bewust ongeldige projecten af.
- XML-parser: 3 bestanden geldig (`Info.plist`, privacyverklaring en gedeeld Xcode-schema).
- `bash -n scripts/build-ios.sh`: exit 0.
- Testdefinities geteld tegen verwacht aantal: 21 Swift Testing-tests.
- Onafhankelijke bronreview: audioconversie naar worker verplaatst; resampler wordt bij Stop geleegd; fouten tijdens finalisatie blijven zichtbaar; niet-opgeslagen tekst blokkeert een andere/nieuwe sessie.

## Nog niet aangetoond

- Swift-tests: **0 uitgevoerd**. Swift ontbreekt lokaal; de opdracht `swift test` kan hier niet starten.
- Xcode-builds voor simulator en iPhone: niet uitgevoerd.
- iPhone-installatie, Nederlandse herkenningskwaliteit, toestemming, schermvergrendeling, herstel na telefoongesprekken en toegankelijkheid: niet op een toestel uitgevoerd.
- Echte opname van 195 minuten: niet uitgevoerd. Een test met gesimuleerde tijd bewijst alleen documentgedrag, niet microfoon-, batterij- of achtergrondwerking.

Het project is broncode die op een macOS-runner moet worden gebouwd en daarna volgens [TOESTELTEST.md](TOESTELTEST.md) moet worden getest. Er is nog geen installatiebestand. Publicatie op GitHub en een workflowrun wachten op de keuze van de eigenaar.
