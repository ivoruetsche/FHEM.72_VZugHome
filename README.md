# FHEM.72_VZugHome
Dieses Module ist für FHEM und bindet V-ZUG Haushaltsgeräte, welche mit der Erweiterung [V-ZUG-Home](https://home.vzug.com) ausgestattet sind in FHEM ein.
Aktuell werden readings der Geräte abgerufen und an FHEM übergeben.

Ältere Firmware Versionen der V-Zug-Home Module reagieren etwas zu Entspannt auf Anfrage und lehnen Anfragen ab, was bei neueren nur noch relativ selten vorkommt.  

## Installation
Die Erweiterung 72_VZugHome.pm muss in das entsprechende FHEM Verzeichnis kopiert werden, in der Regel ist das /opt/fhem/FHEM/ oder via [FHEM update](https://wiki.fhem.de/wiki/Update#update):

Repository hinzufügen:

    update add https://raw.githubusercontent.com/ivoruetsche/FHEM.72_VZugHome/master/controls_VZugHome.txt

Auflisten der Repositories:

    update list

Check auf Updates:

    update check

V-Zug-Home Module hinzufügen/updaten:

    update 72_VZugHome.pm

## Haushaltsgeräte in FHEM definieren
    define <MyDeviceName> VZugHome <appliance IP or DNS Name> <Timeout> <username> <passwword>

* MyDeviceName: Beliebiger Name des Gerätes
* IP or DNS Name: IP Adresse oder DNS Name des Gerätest
* Timeout: Sekunden, wie lange FHEM auf die Antwort vom V-Zug-Home Gerät warten soll (z.B. 3)
* Username: \(Optional) Benutzername, falls für V-Zug-Home ein Benutzername und Passwort definiert wurde
* Password: \(Optional) Passwort, falls für V-Zug-Home ein Benutzername und Passwort definiert wurde

### Beispiel:

    define EmmasBackofen VZugHome 192.168.0.55 3

### Mit Benutzername und Passwort:

    define EmmasBackofen VZugHome 192.168.0.55 3 myUser myPass

## Attribute
    attr <MyDeviceName> Interval <Interval>

* Interval: Sekunden, in welchem Intervall das Endgerät abgefragt werden soll (z.B. 15)

### Beispiel:

    attr EmmasBackofen Interval 15

## Readings
Die Namen der Readings können je nach Endgerät verschieden sein und werden auch von diesem vergegeben. Es können sich auch Values von Endgerät zu Endgerät unterscheiden.

# Offene Punkte
- [ ] GET implementieren
- [ ] Error Code filtern bzw. auswerten (VzAiDeviceStatus.error.code, VzHhFwVersion.error.code, VzHhFwVersion.error.message) [400: OK / 500: OK / 503: OK (2020081603)] 
- [X] Logging bereinigen (verbosity berücksichtigen, zur Zeit wird alles geloggt) (2020081602)
- [X] HTML Text für Hilfe schreiben (2020081601)
- [ ] Code cleanup
- [ ] Mögliche Set's implementieren
