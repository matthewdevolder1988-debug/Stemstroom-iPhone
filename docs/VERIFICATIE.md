# Verificatie — 6 oktober 2026

## Uitgevoerd op Windows

- `node scripts/check-project.mjs`: exit 0; 7 unieke Swift-bronbestanden, alle object- en bestandsverwijzingen geldig. IJking wees eerst 2 bewust ongeldige projecten af.
- XML-parser: 3 bestanden geldig (`Info.plist`, privacyverklaring en gedeeld Xcode-schema).
- `bash -n scripts/build-ios.sh`: exit 0.
- Testdefinities geteld tegen verwacht aantal: 21 Swift Testing-tests.
- Onafhankelijke bronreview: audioconversie naar worker verplaatst; resampler wordt bij Stop geleegd; fouten tijdens finalisatie blijven zichtbaar; niet-opgeslagen tekst blokkeert een andere/nieuwe sessie.

## Uitgevoerd op de macOS-runner

[Build 37507551927](https://github.com/matthewdevolder1988-debug/Stemstroom-iPhone/actions/runs/37507551927), commit `207791c65996c03e45438dc99d7bab287d4c8c72`, standaardrunner `macos-26-intel`:

- Xcode 26.6 (17F113), Swift 6.3.3.
- `swift test`: **21 tests in 2 suites geslaagd**.
- `xcodebuild` voor iOS Simulator: **BUILD SUCCEEDED**.
- `xcodebuild` voor iPhone: **BUILD SUCCEEDED**.
- Ongetekende IPA opgehaald; SHA-256 komt overeen met het buildartifact; appbinary aanwezig in de Payload-map.
- SHA-256 van de release-IPA: `95cd9b568510dc7f930428cc838577380472a901046ea9801ba4ec5ee7a09794`.

## Geblokkeerde simulatorcontrole

De volledige workflow is **rood door de simulatorcontrole**. Beide compileerstappen en de 21 tests zijn geslaagd; de app mag daarom niet als volledig getest worden beschreven.

De eerste poging op de ARM-runner liep vast bij starten van de app. Verdere diagnostiek op ARM en Intel toonde timeouts tijdens `simctl bootstatus`, terwijl iOS nog `Waiting on Data Migration` rapporteerde. Een diagnostische ARM-screenshot toont het Apple-opstartscherm, niet Stemstroom. Ook op de Intel-runner werd de app niet gestart. Er is geen geslaagde visuele controle of runtime-spraaktest. Verdere herhaling is gestopt; de eerste start wordt op een echte iPhone gecontroleerd.

## Nog niet aangetoond

- iPhone-installatie, Nederlandse herkenningskwaliteit, toestemming, schermvergrendeling, herstel na telefoongesprekken en toegankelijkheid: niet op een toestel uitgevoerd.
- Echte opname van 195 minuten: niet uitgevoerd. Een test met gesimuleerde tijd bewijst alleen documentgedrag, niet microfoon-, batterij- of achtergrondwerking.

Het installatiebestand moet met een persoonlijk Apple-account worden ondertekend en daarna volgens [TOESTELTEST.md](TOESTELTEST.md) worden getest. De openbare repository en gratis standaardrunner zijn door de eigenaar goedgekeurd. Documentatiecommits na de genoemde build wijzigen de app, tests en buildscripts niet.
