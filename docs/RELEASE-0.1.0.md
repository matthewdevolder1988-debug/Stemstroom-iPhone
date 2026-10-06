# Stemstroom 0.1.0 — persoonlijke testversie

Nederlandse spraak-naar-tekst voor iPhone 13 en nieuwer met iOS 26. Live tekst, Kopieer alles, lokale opslag, herstel van tekst en een achtergrondopname zonder ingestelde sessielimiet.

## Installeren vanaf Windows

Download **Stemstroom-unsigned.ipa** en volg de [Windows-installatiehandleiding](https://github.com/matthewdevolder1988-debug/Stemstroom-iPhone#installeren-met-altstore-classic-op-windows). AltStore Classic ondertekent de app met je eigen Apple-account. Een gratis account vereist vernieuwing binnen zeven dagen. Een IPA opent niet rechtstreeks als app: de persoonlijke ondertekening is nodig.

## Gemeten bewijs

21 kerntests slagen. Xcode-builds voor iPhone en simulator slagen. De SHA-256 van het gedownloade pakket is vergeleken met het buildartifact. De app gebruikt geen betaalde transcriptie-API of eigen server.

De cloudsimulator bleef hangen tijdens de eerste iOS-configuratie, vóór het appscherm kon worden gecontroleerd. De volledige workflow is daardoor rood, hoewel de tests en beide builds slagen. Dit is nog geen op een fysieke iPhone gevalideerde versie. Eerste start, Nederlandse herkenning en een opname van minstens 3 uur en 15 minuten met vergrendeld scherm moeten nog worden getest. Telefoongesprekken, procesbeëindiging en een lege batterij kunnen audio onderbreken; de app kan ontbrekende audio niet reconstrueren. Zie de [toesteltest](https://github.com/matthewdevolder1988-debug/Stemstroom-iPhone/blob/main/docs/TOESTELTEST.md) en het [verificatierapport](https://github.com/matthewdevolder1988-debug/Stemstroom-iPhone/blob/main/docs/VERIFICATIE.md).
