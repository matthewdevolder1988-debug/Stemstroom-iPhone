# Stemstroom voor iPhone

Persoonlijke spraak-naar-tekst-app voor iPhone 13 en nieuwer met iOS 26. Eén scherm voor live tekst, Start/Stop en Kopieer alles. De app heeft geen ingestelde sessielimiet; taalherkenning gebeurt op het toestel. Beschikbaarheid van de gekozen taal en het lokale model wordt bij het starten gecontroleerd.

**Leveringsstatus:** dit is een broncodeproject. De app is in deze Windows-omgeving niet met Xcode gebouwd, niet geïnstalleerd op een iPhone en niet gedurende drie uur getest. Een succesvolle CI-build bewijst compilatie; achtergrondopname, herkenningskwaliteit en duur vereisen de [toesteltest](docs/TOESTELTEST.md).

## Gebruik

Kies je taal en tik op **Start**. Sta microfoon en spraakherkenning toe. De eerste voorbereiding kan internet en vrije opslag nodig hebben voor een taalmodel van Apple. Daarna hoort de transcriptie lokaal te werken. Tik op **Stop** om de laatste tekst af te werken, en op **Kopieer alles** om de tekst elders te plakken. Eerdere sessies blijven lokaal bewaard.

Vergrendelen of naar een andere app gaan hoort de opname niet te stoppen. Een gesprek, weggevallen microfoon, volle audiobuffer, afgesloten proces of lege batterij kan wel onderbreken. De app moet dat zichtbaar markeren; gemiste audio kan achteraf niet worden teruggehaald. Bewaar belangrijke tekst ook buiten de app voordat je haar verwijdert of opnieuw installeert.

## Van Windows naar een installatiebestand

Windows kan dit iOS-project niet compileren. De meegeleverde handmatige GitHub Actions-workflow gebruikt een tijdelijke Mac met Xcode. Er zijn nog geen repository, workflowrun of downloadbaar installatiebestand aangemaakt.

1. Maak met GitHub Desktop een **nieuwe, aparte repository** `Stemstroom-iPhone`, buiten de Brindero-werkmap.
2. Kopieer de volledige inhoud van deze projectmap naar die nieuwe repository, inclusief de verborgen map `.github`. `Package.swift`, `App`, `Sources`, `Tests`, `scripts` en `Stemstroom.xcodeproj` horen rechtstreeks in de repositorywortel. Kopieer geen `.git`-map of andere Brindero-bestanden.
3. Commit de bestanden en kies **Publish repository**, met **Keep this code private** aangevinkt.
4. Open de repository op GitHub. Controleer je Actions-verbruik en budget voordat je bouwt. Kies **Actions → Bouw Stemstroom voor iPhone → Run workflow** op de standaardtak. Een upload of commit start deze workflow niet vanzelf.
5. Wacht op een groene run. De workflow voert `swift test` uit, bouwt voor de simulator en voor iPhone en verpakt de iPhone-app zonder ondertekening.
6. Download onder **Artifacts** `Stemstroom-iPhone-unsigned`. Pak de downloadzip op Windows uit. Het bestand `Stemstroom-unsigned.ipa` daarin is het installatiepakket; pak de IPA zelf niet uit.

De artifact bevat ook een SHA-256 en gebruikte toolversies. In `Stemstroom-bouwlog` staan volledige test- en bouwlogs. Download binnen drie dagen; daarna kunnen de artifacts vervallen. Een rode run levert geen bruikbaar installatiebestand: lees dan de eerste fout in de bouwlog.

GitHub biedt voor private repositories een maandelijkse hoeveelheid minuten en opslag. Mac-runners tellen anders dan Linux; boven je tegoed kan gebruik geld kosten of blokkeren. Stel je budget passend in en controleer het actuele tegoed. Dit is geen belofte van onbeperkt gratis bouwen. [GitHub Actions-facturatie](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

Een **openbare** repository kan dezelfde workflow met de standaardrunner gratis gebruiken; je broncode en buildlogs zijn dan openbaar. Kies die zichtbaarheid alleen bewust. Je hoeft voor deze app geen transcripties, Apple-inloggegevens of persoonlijke bestanden te uploaden. [GitHub: gratis gebruik van standaardrunners](https://docs.github.com/en/billing/concepts/product-billing/github-actions#free-use-of-github-actions).

## Installeren met AltStore Classic op Windows

Volg de [officiële Windows-handleiding van AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) voor AltServer, iTunes/iCloud, USB-vertrouwen en wifi-synchronisatie. Installeer AltStore via AltServer op je iPhone. Volg op het toestel de aanwijzingen voor het vertrouwen van je ontwikkelaarsprofiel en **Instellingen → Privacy en beveiliging → Ontwikkelaarsmodus**.

Je voert je Apple-inloggegevens zelf in de officiële installatie-app in. De bouwprocedure gebruikt geen Apple-account, certificaten of GitHub-secrets.

Zet `Stemstroom-unsigned.ipa` in de app **Bestanden** op je iPhone, bijvoorbeeld via iCloud Drive. Houd AltServer op Windows bereikbaar via USB of hetzelfde wifi-netwerk. Open **AltStore Classic → My Apps → +**, selecteer de IPA en laat AltStore haar ondertekenen en installeren. Installeer latere versies met hetzelfde account en zonder Stemstroom eerst te verwijderen. Exporteer belangrijke tekst vooraf.

Een gratis persoonlijk Apple-account vereist vernieuwing binnen **zeven dagen**. Open geregeld **My Apps → Refresh All** terwijl AltServer bereikbaar is; controleer de resterende dagen. Automatisch vernieuwen is geen garantie. Gratis accounts hebben ook een limiet voor actieve sideload-apps. Zie [AltStore: gebruik en vernieuwen](https://faq.altstore.io/altstore-classic/your-altstore) en [AltServer](https://faq.altstore.io/altstore-classic/altserver).

## Op een Mac bouwen

Open `Stemstroom.xcodeproj` in Xcode 26. Selecteer schema **Stemstroom**. Voor een fysieke iPhone kies je onder **Signing & Capabilities** je eigen Personal Team en zo nodig een unieke bundle identifier. Het project bevat bewust geen vooraf gekozen team. Voor een simulator is geen persoonlijk team nodig.

Voor dezelfde controles en ongetekende IPA als in CI:

```bash
bash scripts/build-ios.sh
```

De Foundation-kern heeft afzonderlijke tests via `swift test`; het Xcode-schema compileert de twee kernbestanden rechtstreeks in de appmodule. Er zijn geen externe Swift-packages, CocoaPods of XcodeGen nodig. De Swift-taalmodus is 5; de toolchain komt uit Xcode 26.

Ook op Windows kun je met `node scripts/check-project.mjs` de projectstructuur en bronverwijzingen controleren. De controle ijkt zichzelf op twee bekende fouten. Dit compileert geen Swift en test geen microfoon, herkenning of achtergrondopname.

## Bouwomgeving en herkomst

De workflow kiest `macos-26` en Xcode 26.6 expliciet. Deze combinatie staat in de [officiële runnerinventaris](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md). `actions/checkout@v7` en `actions/upload-artifact@v7` volgen de actuele [checkout-documentatie](https://github.com/actions/checkout) en [artifact-documentatie](https://github.com/actions/upload-artifact). Gecontroleerd op 6 oktober 2026; beschikbare runnerimages kunnen later wijzigen.

De app gebruikt Apple-systeemonderdelen SwiftUI, AVFAudio, Foundation en Speech, waaronder [DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber) en [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer). Er worden geen externe modellen, lettertypen, afbeeldingen of runtimebibliotheken meegeleverd. Apple beheert de spraakmodellen op het toestel. Achtergrondaudio is vastgelegd in [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes).

Transcripties blijven in de appopslag; er is geen eigen server, account of analysetelemetrie. De privacyverklaring bevat daarom geen tracking, verzamelde gegevens of gebruikte required-reason-API-categorieën. Eventuele iCloud-reservekopieën vallen onder je eigen iPhone-instellingen.
