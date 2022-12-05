#!/usr/bin/env bash
set -e
clear

refcopy_moonraker_service="moonraker_template.service"
refcopy_moonraker_env="moonraker_template.env"
refcopy_moonraker_conf="moonraker_template.conf"
refcopy_klipper_service="klipper_template.service"


nextInstanceId=2
foundInstances=(
)

#=================================================#
#================== Hauptmenü  ===================#
#=================================================#
function mainMenue() {

  local input;

  # UI
  clear
  echo -e "/=======================================================\\"
  echo -e "| Mit diesem Skript lassen sich auf einem Raspberry PI  |"
  echo -e "| neue Klipperinstanzen automatisch installieren oder   |"
  echo -e "| deinstallieren.                                       |"
  echo -e "|                                                       |"
  echo -e "| ${yellow}WARNUNG:${white}                                              |"
  echo -e "| ${yellow}Verwendung auf eigene Gefahr!                       ${white}  |"
  echo -e "|                                                       |"
  echo -e "| Bitte wähle deine Aktion                              |"
  echo -e "| i) Neue Instanz installieren                          |"
  echo -e "| u) Eine Instanz deinstallieren                        |"
  echo -e "| e) Zum beenden des Sktripts                           |"
  echo -e "\=======================================================/"


  while true; do
    read -p "${cyan}###### Wähle eine Aktion:${white} " input
    case "${input}" in
      I|i)
        installInstance
        break;;
      U|u)
        uninstallInstance
        break;;
      E|e)
        clear
        break;;
      *)
        echo -e "\n${magenta}###### Fehlerhafte Eingabe!${white}";;
    esac
  done && input=""

  exit
}

#=================================================#
#===== suche nach bestehenden Instanzen  =========#
#=================================================#
function getInstances() {
  local searchPath="/etc/systemd/system/"
  for i in {1..20}
  do
    if [ -f "${searchPath}moonraker${i}.service" ]; then
      foundInstances+=( $i )
      nextInstanceId=$((i+1))
    fi
  done
}

#=================================================#
#============ Instanz deinstallieren  ============#
#=================================================#
function uninstallInstance() {

  getInstances

  # UI
  clear
  echo -e "/=======================================================\\"
  echo -e "| DEINSTALLIEREN                                        |"
  echo -e "|-------------------------------------------------------|" 
  echo -e "| Wähle die Instanz welche du deinstallieren möchtest   |"
  echo -e "|                                                       |"
  for t in ${foundInstances[@]}; do
    echo -e "| ${t}.)\t Gefunden                                       |"
  done
  echo -e "|                                                       |"
  echo -e "| Gebe die Zahl für die zu deinstallierende Instanz ein |"
  echo -e "| oder E zum beenden                                    |"
  echo -e "\=======================================================/" 

  # Auswahl durch den Benutzer
  regex="^[1-9][0-9]*$"
  while [[ ! ${input} =~ ${regex} ]]; do
    read -p "${cyan}###### Nummer für die Klipper Instanz welche deinstalliert werden soll:${white} " -i "" -e input

    if [[ ${input} =~ ${regex} ]]; then
      instance_count="${input}"
      echo -e "${white}   [➔] Instanz wird deinstalliert: ${instance_count}\n"
      break
    elif [[ ${input} == "E" || ${input} == "e" ]]; then
      return
    else
      echo -e "\n${magenta}###### Fehlerhafte Eingabe!${white}"
    fi
  done && input=""

  local moonrakerServiceFile="/etc/systemd/system/moonraker${instance_count}.service"
  local moonrakerEnvFile="/home/pi/printer_data/systemd/moonraker${instance_count}.env"
  local moonrakerConfFile="/home/pi/klipper_config/moonraker${instance_count}.conf"
  local klipperServiceFile="/etc/systemd/system/klipper${instance_count}.service"

  # Moonraker stoppen und deinstallieren
  if [ -f "${moonrakerServiceFile}" ]; then
    systemctl stop moonraker${instance_count}
    systemctl disable moonraker${instance_count}.service
    rm $moonrakerServiceFile
  fi

  # klipper stoppen und deinstallieren
  if [ -f "${klipperServiceFile}" ]; then
    systemctl stop klipper${instance_count}
    systemctl disable klipper${instance_count}.service
    rm $klipperServiceFile
  fi

  # Entferne Moonraker ENV Datei
  if [ -f "${moonrakerEnvFile}" ]; then
    rm $moonrakerEnvFile
  fi

  # Verschiebe Moonraker CONF
  if [ -f "${moonrakerConfFile}" ]; then
    mv $moonrakerConfFile $moonrakerConfFile.old.bak
  fi
}


#=================================================#
#========== Neue Instanz installieren  ===========#
#=================================================#
function installInstance() {

  local instance_count
  getInstances

  # UI
  clear
  echo -e "/=======================================================\\"
  echo -e "| Bitte wähle die Nummer für die neue Klipper Instanz   |"
  echo -e "| welche installiert werden soll. Diese sollte          |"
  echo -e "| aufsteigend sein, kann nur einmal vergeben sein!      |"
  echo -e "|                                                       |"
  echo -e "| ${yellow}WARNUNG:${white}                                              |"
  echo -e "| ${yellow}Zu viele Instanzen können zum Systemcrash führen!.  ${white}  |"
  echo -e "|                                                       |"
  echo -e "| Tippe E zum abbrechen                                 |"
  echo -e "\=======================================================/"

  # Auswahl durch den Benutzer
  regex="^[1-9][0-9]*$"
  while [[ ! ${input} =~ ${regex} ]]; do
    read -p "${cyan}###### Nummer für die Klipper Instanz welche installiert werden soll:${white} " -i "${nextInstanceId}" -e input

    if [[ ${input} =~ ${regex} ]]; then
      instance_count="${input}"
      echo -e "${white}   [➔] Instanz wird installiert: ${instance_count}\n"
      break
    elif [[ ${input} == "E" || ${input} == "e" ]]; then
      return
    else
      echo -e "\n${magenta}###### Fehlerhafte Eingabe!${white}"
    fi
  done && input=""

  run_setup "${instance_count}"
}

#=================================================#
#=============== Setup ausführen =================#
#=================================================#
function run_setup() {
  local instance_count=${1}
  local nextMoonrakerPort=$((7125+instance_count))

  local originalMoonrakerServiceFile="/etc/systemd/system/moonraker.service"
  local originalMoonrakerConfFile="/home/pi/klipper_config/moonraker.conf"
  local originalKlipperServiceFile="/etc/systemd/system/klipper.service"
  local originalMoonrakerEnvFile="/home/pi/printer_data/systemd/moonraker.env"

  local moonrakerServiceFile="/etc/systemd/system/moonraker${instance_count}.service"
  local moonrakerEnvFile="/home/pi/printer_data/systemd/moonraker${instance_count}.env"
  local moonrakerConfFile="/home/pi/klipper_config/moonraker${instance_count}.conf"
  local klipperServiceFile="/etc/systemd/system/klipper${instance_count}.service"
  local printerConfigFile="/home/pi/klipper_config/printer${instance_count}.cfg"

  # Prüfe ob Dateien existieren!
  if [ -f "${moonrakerServiceFile}" ]; then
    echo -e "\n${magenta}###### Instanz bereits erzeugt!${white}"
    return
  fi
  if [ -f "${klipperServiceFile}" ]; then
    echo -e "\n${magenta}###### Instanz bereits erzeugt!${white}"
    return
  fi
  if [ -f "${moonrakerEnvFile}" ]; then
    echo -e "\n${magenta}###### Instanz bereits erzeugt!${white}"
    return
  fi

  # Lege Verzeichnis an und lade die Daten aus GDrive
  mkdir -p /tmp/copy_setup_files
  cd /tmp/copy_setup_files

  # Kopiere die originale Moonraker Servicedatei, passe diese an
  cp $originalMoonrakerServiceFile $refcopy_moonraker_service
  sed -i "s/EnvironmentFile=\/home\/pi\/printer_data\/systemd\/moonraker.env/EnvironmentFile=\/home\/pi\/printer_data\/systemd\/moonraker${instance_count}.env/" $refcopy_moonraker_service

  # Kopiere die originale Moonraker Enviromentdatei, passe diese an
  cp $originalMoonrakerEnvFile $refcopy_moonraker_env
  sed -i "s/moonraker.conf/moonraker${instance_count}.conf/" $refcopy_moonraker_env
  sed -i "s/moonraker.log/moonraker${instance_count}.log/" $refcopy_moonraker_env

  # Kopiere die originale Moonraker Konfigurationsdatei, passe diese an
  cp $originalMoonrakerConfFile $refcopy_moonraker_conf
  for i in {0..20}
  do
    if i==0
    then
      sed -i "s/klippy_uds_address: \/tmp\/klippy_uds//" $refcopy_moonraker_conf
    else
      sed -i "s/klippy_uds_address: \/tmp\/klippy${i}_uds//" $refcopy_moonraker_conf
    fi
  done
  sed -i "s/port: 7125/port: ${nextMoonrakerPort}\r\nklippy_uds_address: \/tmp\/klippy${instance_count}_uds/" $refcopy_moonraker_conf

  # Kopiere die originale Klipper Servicedatei, passe diese an
  cp $originalKlipperServiceFile $refcopy_klipper_service
  sed -i "s/Before=moonraker.service/Before=moonraker${instance_count}.service/" $refcopy_klipper_service
  sed -i "s/Alias=klippy/Alias=klippy${instance_count}/" $refcopy_klipper_service
  sed -i "s/printer.cfg/printer${instance_count}.cfg/" $refcopy_klipper_service
  sed -i "s/klippy.log/klippy${instance_count}.log/" $refcopy_klipper_service
  sed -i "s/klippy_uds/klippy${instance_count}_uds/" $refcopy_klipper_service

  # Dateien in das reale Ziel kopieren
  echo -e "${white}   [➔] Lege neue Dateien an"
  cp $refcopy_moonraker_service $moonrakerServiceFile
  cp $refcopy_moonraker_conf $moonrakerConfFile
  cp $refcopy_moonraker_env $moonrakerEnvFile
  cp $refcopy_klipper_service $klipperServiceFile
  touch $printerConfigFile

  # Berechtigungen setzen
  echo -e "${white}   [➔] Setze Berechtigungen"
  chmod 755 $moonrakerServiceFile
  chmod 755 $moonrakerConfFile
  chmod 755 $moonrakerEnvFile
  chmod 755 $klipperServiceFile
  chmod 755 $printerConfigFile
  chmod u+x $moonrakerServiceFile
  chmod u+x $klipperServiceFile

  # Starte die Services
  echo -e "${white}   [➔] Starte die neue Klipper Instanz"
  systemctl enable klipper${instance_count}.service
  systemctl start klipper${instance_count}

  echo -e "${white}   [➔] Starte die neue Moonraker Instanz"
  systemctl enable moonraker${instance_count}.service
  systemctl start moonraker${instance_count}

  # Daten löschen
  cd ~
  rm -R /tmp/copy_setup_files

  # Fertig
  echo -e "/=======================================================\\"
  echo -e "| Installation abgeschlossen                            |"
  echo -e "|                                                       |"
  echo -e "| Gehe auf die Webseite und füge einen neuen Drucker    |"
  echo -e "| hinzu.                                                |"
  echo -e "| Unter Mainsail oben rechts auf die                    |"
  echo -e "| Zahnräder -> Drucker -> Hinzufügen                    |"
  echo -e "| Verwende deine IP/Hostname und den Port ${nextMoonrakerPort}          |"
  echo -e "\=======================================================/"
}

#=================================================#
#==================== Start ======================#
#=================================================#

if [ "$EUID" -ne 0 ]
  then echo "Das Skript muss mit sudo gestartet werden!"
  exit
fi

mainMenue
