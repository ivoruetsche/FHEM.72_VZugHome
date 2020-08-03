     __      __   _______    _  _____        _    _  ____  __  __ ______                   ______ _    _ ______ __  __ 
     \ \    / /  |___  / |  | |/ ____|      | |  | |/ __ \|  \/  |  ____|                 |  ____| |  | |  ____|  \/  |
      \ \  / /_____ / /| |  | | |  __ ______| |__| | |  | | \  / | |__       ___  _ __    | |__  | |__| | |__  | \  / |
       \ \/ /______/ / | |  | | | |_ |______|  __  | |  | | |\/| |  __|     / _ \| '_ \   |  __| |  __  |  __| | |\/| |
        \  /      / /__| |__| | |__| |      | |  | | |__| | |  | | |____   | (_) | | | |  | |    | |  | | |____| |  | |
         \/      /_____|\____/ \_____|      |_|  |_|\____/|_|  |_|______|   \___/|_| |_|  |_|    |_|  |_|______|_|  |_|

# FHEM.72_VZugHome
Dieses Module ist für FHEM und bindet V-ZUG Haushaltsgeräte, welche mit der Erweiterung [V-ZUG-Home](https://home.vzug.com) ausgestattet sind in FHEM ein.
Aktuell werden readings der Geräte abgerufen und an FHEM übergeben.

Ältere Firmware Versionen der V-Zug-Home Module reagieren etwas zu Entspannt auf Anfrage und lehnen Anfragen ab, was bei neueren nur noch relativ selten vorkommt.  

## Installation
Die Erweiterung 72_VZugHome.pm muss in das entsprechende FHEM Verzeichnis kopiert werden, in der Regel ist das /opt/fhem/FHEM/

## Haushaltsgerätes in FHEM definieren
    define <MyDeviceName> VZugHome <appliance IP or DNS Name> <Timeout> <username> <passwword>

* MyDeviceName: Beliebiger Name des Gerätes
* IP or DNS Name: IP Adresse oder DNS Name des Gerätest
* Timeout: Sekunden, wie lange FHEM auf die Antwort vom V-Zug-Home Gerät warten soll (z.B. 3)
* Username: \(Optional) Benutzername, falls für V-Zug-Home ein Benutzername und Passwort definiert wurde
* Password: \(Optional) Passwort, falls für V-Zug-Home ein Benutzername und Passwort definiert wurde

### Beispiel:

    define EmmasBackofen VZugHome 192.168.0.55 3 myUser myPass

## Attribute
    attr <MyDeviceName> Interval <Interval>

* Interval: Sekunden, in welchem Intervall das Endgerät abgefragt werden soll (z.B. 15)

### Beispiel:

    attr EmmasBackofen Interval 15

## Readings
Die Namen der Readings können je nach Endgerät verschieden sein und werden auch von diesem vergegeben. Es können sich auch Values von Endgerät zu Endgerät unterscheiden.