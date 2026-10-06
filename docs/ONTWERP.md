# Stemstroom voor iPhone

Persoonlijke app voor doorlopende spraak-naar-tekst, zonder account, backend of betaalde transcriptiedienst.

## Afgesproken gedrag

- Eén opnamescherm met groeiende tekst en Kopieer alles.
- Sessies van meer dan drie uur hebben geen ingestelde tijdslimiet.
- Vergrendelen en wisselen van app beëindigen de opname niet.
- Alleen Stop beëindigt de sessie bewust. Stilte beëindigt haar niet.
- iOS kan de microfoon onderbreken: telefoongesprekken, procesbeëindiging, lege accu en ontbrekende rechten blijven echte beperkingen. Toon onderbrekingen en hervat wanneer iOS dit toestaat; verzin geen ontbrekende tekst.

## Platformkeuze

iPhone 13 en nieuwer, met iOS 26 of hoger. Alleen Nederlands (België/Nederland). SwiftUI, AVAudioEngine, SpeechAnalyzer en DictationTranscriber met progressiveLongDictation. Controleer taal- en modelbeschikbaarheid op het toestel. Gebruik uitsluitend lokale herkenning; val nooit stilzwijgend terug op een server. De gebruiker heeft uitsluitend Windows: bouwen via een macOS-runner en vervolgens persoonlijk installeren via AltStore Classic.

## Gegevensstroom

Microfoon → begrensde audiostream → SpeechAnalyzer → voorlopige/finale tekst → lokaal document. Bestendige tekst en één vervangbare voorlopige passage blijven gescheiden. Oude voorlopige resultaten worden vervangen, niet telkens toegevoegd. Audio blijft niet uren in het geheugen. Een volle buffer geeft een zichtbare onderbreking; geen stil gegevensverlies.

Sla na tekstwijzigingen lokaal en atomair op. Bewaar bestanden met bescherming die schrijven na de eerste ontgrendeling toestaat. Nieuwe sessies krijgen een eigen bestand; vorige sessies blijven beschikbaar. Onderbrekingsmarkeringen gaan mee in tekstexport.

## Scherm

Native navigatie, systeemlettertype, Dynamic Type, licht/donker, tekstselectie. Bovenaan taal, status en tijd; centraal tekst; onderaan vaste Start/Stop en Kopieer alles. Taalkeuze is geblokkeerd tijdens een sessie. Geen timer of stilte-detectie stopt de sessie. Een nieuwe sessie verwijdert geen eerdere tekst.

## Verificatie

Swift-tests voor voorlopige/finale tekst, hervatten, opslag en meer dan drie uur gesimuleerde tekst. Daarna een Xcode-simulatorbuild en een echte iPhone-proef van minstens 3 uur en 15 minuten met vergrendeling, stilte, gespreksonderbreking en stop. Windows kan geen iOS-build of echte achtergrondopname verifiëren. Meld die grenzen expliciet.

## Installatie

Een gratis Apple Personal Team heeft profielen die na zeven dagen verlopen. Installatie via Xcode vereist een Mac. Windows kan een vooraf op een Mac gebouwde IPA ondertekenen/installeren via AltStore Classic, maar compileert de app niet zelf. Geen publicatie of betaalde diensten zonder opdracht.
