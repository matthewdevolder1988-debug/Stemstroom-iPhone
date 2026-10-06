# Toesteltest: echte opname van 3 uur en 15 minuten

**Status: niet uitgevoerd.** Een gesimuleerde lange tekst, groene Swift-test, simulatorbuild of verstreken timer bewijst geen werkende microfoon of achtergrondtranscriptie.

## Voorbereiding en bewijs

Begin met iPhone 13 en herhaal op het recentste beschikbare doeltoestel. Vermeld onbeproefde modellen expliciet; één telefoon bewijst geen volledige reeks. Installeer iOS 26 of nieuwer, noteer exacte iOS-versie, model, gekozen taal, appversie, buildcommit en het SHA-256 van de IPA. Test elke gewenste taal afzonderlijk. Verifieer eerst dat Apple het lokale taalmodel op dat toestel beschikbaar stelt.

Gebruik gesproken referentiezinnen met herkenbare tijdmarkeringen, bijvoorbeeld "controle dertig minuten", uit een tweede toestel of uitgesproken door de tester. Gebruik verstaanbare spraak, normale stiltes en achtergrondgeluid dat past bij het echte gebruik. Een audiospoor op het tweede toestel kan als referentie dienen. Leg kloktijden vast buiten Stemstroom.

Begin voldoende opgeladen, noteer batterijpercentage en vrije opslag, haal de lader los en schakel Energiebesparingsmodus voor de basisrun uit. Noteer elke wijziging in stroomvoorziening, temperatuur of energiestand. Download het taalmodel vooraf. Exporteer bestaande belangrijke sessies voordat je herstelgedrag beproeft.

## Ononderbroken basisrun van minimaal 195 minuten

| Tijd vanaf Start | Handeling | Vereist resultaat en te bewaren bewijs |
| --- | --- | --- |
| 00:00 | Start, spreek een herkenbare beginzin. | Live tekst verschijnt; juiste taal; begin- en kloktijd genoteerd. |
| 00:05 | Vergrendel de iPhone en laat spraak doorgaan. | Na ontgrendelen bevat de tekst gesproken controlezinnen uit de vergrendelde periode. |
| 00:30 | Houd tien minuten echte stilte met vergrendeld scherm. | De sessie eindigt niet; spraak na stilte verschijnt weer. |
| 00:45 | Gebruik een andere app gedurende vijftien minuten. | Terugkeer toont nieuwe tekst uit de achtergrondperiode. |
| 01:00 | Spreek een unieke controlezin; noteer batterij en warmte. | Zin aanwezig, geen verdubbeling van voorlopige tekst; app blijft bedienbaar. |
| 01:30 | Vergrendel opnieuw en laat spraak doorgaan. | Geen onverklaarde gaten; opgeslagen tekst blijft beschikbaar. |
| 02:00 | Schakel vliegtuigstand in, wifi uit, met model al beschikbaar. | Nieuwe spraak blijft lokaal verschijnen; geen netwerk nodig voor herkenning. |
| 03:00 | Spreek een unieke controlezin, noteer batterij. | De microfoon en herkenning werken nog na drie echte uren. |
| 03:15 of later | Spreek een slotzin en tik op Stop. | Slotzin wordt verwerkt; status stopt; Kopieer alles bevat begin, controles en slot. |
| Na Stop | Sluit en heropen de app; open de bewaarde sessie. | Tekst is gelijk aan de export; eerdere sessies zijn nog aanwezig. |

Bewaar de volledige tekstexport met de genoteerde kloktijden. Maak screenshots van start, de terugkeer na vergrendeling, drie uur en de gestopte sessie. Markeer ontbrekende referentiezinnen en onverwachte stiltes. Bij een crash of onverwachte stop is de basisrun mislukt, ook als de timer 195 minuten aangeeft.

## Afzonderlijke onderbrekings- en herstelproeven

Deze proeven vervangen de basisrun niet.

| Situatie | Vereist gedrag |
| --- | --- |
| Binnenkomend gesprek; aannemen en beëindigen. | Microfoononderbreking wordt zichtbaar gemarkeerd. Geen verzonnen tekst voor de ontbrekende audio. Hervatten zodra iOS dat toestaat, of een duidelijke actie om opnieuw te beginnen. |
| Microfoonroute wisselt door aansluiten/loskoppelen van een headset. | Geen crash. Nieuwe spraak verschijnt na herstel; een gat wordt gemarkeerd. |
| Microfoon- of spraakrechten weigeren en later weer toestaan. | Duidelijke fout en herstelmogelijkheid; geen schijnbaar actieve opname. |
| Stop direct na een gesproken zin, ook vlak vóór vergrendeling. | Finaliseren en opslaan slagen; geen verdwenen of dubbele slotpassage. |
| Tijdens een korte testsessie de app geforceerd afsluiten en heropenen. | Laatst opgeslagen tekst is terug; app doet niet alsof de opname doorliep. Noteer exact het verlies sinds de laatste autosave. |
| iPhone opnieuw starten en daarna ontgrendelen. | Opgeslagen sessies blijven leesbaar. Een nieuwe opname vereist opnieuw Start. |
| Nieuwe sessie na eerdere sessie starten. | Eerdere tekst wordt niet overschreven; export hoort bij de geselecteerde sessie. |
| Energiebesparingsmodus inschakelen tijdens een aanvullende achtergrondproef. | Feitelijk gedrag, batterij en eventuele onderbrekingen noteren; geen aanname op basis van de basisrun. |

## Geheugen, batterij en opslag

Noteer batterijpercentage bij start, na 60, 120, 180 en 195 minuten en bereken het verschil in procentpunten. Noteer warmtewaarschuwingen, traagheid en eventuele iOS-beëindiging. De run moet op batterij de volledige duur halen of expliciet vermelden wanneer de lader is aangesloten.

Voor een geheugenoordeel is een echte meting nodig, bijvoorbeeld Instruments/Allocations op een aangesloten Mac. Meet procesgeheugen na 15, 60, 120, 180 en 195 minuten. Een grote lineaire groei passend bij bewaarde ruwe audio is een fout; beperkte groei door meer transcriptietekst is verwacht. Voeg meetreeks, piekwaarde en eventuele geheugenwaarschuwingen toe.

Met alleen Windows kun je crashes en mogelijke `JetsamEvent`-meldingen bekijken onder **Instellingen → Privacy en beveiliging → Analyse en verbeteringen → Analysegegevens**, als iOS die heeft geregistreerd. Dat bewijst geen stabiele geheugencurve. Zet geheugen dan op **niet gemeten**, ook als de opname ogenschijnlijk goed verliep. De geheugenacceptatie blijft open tot een echte meting beschikbaar is.

Controleer vrije opslag vóór en na de run en exporteer de bewaarde tekst. Er hoort geen urenlange audiobestandsgroei te zijn. Bewaar ook de onbewerkte JSON-sessie indien die in de testomgeving beschikbaar is; pas bestanden van een echte sessie niet aan om de test te laten slagen.

## Resultaatregistratie

| Veld | In te vullen na de proef |
| --- | --- |
| Tester, datum, iPhone, iOS-versie | Niet uitgevoerd |
| Commit, appversie, IPA SHA-256, taal | Niet uitgevoerd |
| Start/eindkloktijd en echte duur | Niet uitgevoerd |
| Referentiezinnen gevonden/totaal | Niet uitgevoerd |
| Basisrun vergrendeling/stilte/achtergrond/offline | Niet uitgevoerd |
| Onderbrekingen en herstel | Niet uitgevoerd |
| Begin-/eindbatterij, lader, temperatuur | Niet uitgevoerd |
| Geheugenreeks/piek of niet gemeten | Niet gemeten |
| Opslag vóór/na, heropenen, export | Niet uitgevoerd |
| Bewijsbestanden en afwijkingen | Niet uitgevoerd |
| Oordeel en resterende controles | Niet uitgevoerd |

Pas de status bovenaan alleen aan op basis van deze meetgegevens. Houd duur, herkenningskwaliteit, herstel en geheugen als afzonderlijke resultaten; een geslaagde deelproef dekt de rest niet af.
