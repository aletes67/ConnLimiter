#!/bin/bash

TIME="$1"
MAXCOUNT=50

# Converte il tempo fornito in un formato comprensibile per il comando date
CURRENT_TIME=$(date -d "today $TIME" +"%H:%M")

# Calcola due minuti prima e un minuto dopo il tempo fornito
TIME_MINUS_TWO=$(date -d "$CURRENT_TIME today - 2 minutes" +"%H:%M")
TIME_PLUS_ONE=$(date -d "$CURRENT_TIME today + 1 minute" +"%H:%M")

echo "TIME: $TIME_MINUS_TWO $TIME_PLUS_ONE"

# Assicurati che `filtra.sh` e `banna.sh` siano nella stessa directory e abbiano i permessi di esecuzione
./filtra.sh "$TIME_MINUS_TWO" "$TIME_PLUS_ONE"

# Controlla che `filtra.sh` abbia terminato prima di proseguire
if [ $? -ne 0 ]; then
  echo "filtra.sh ha incontrato un errore."
  exit 1
fi

# Inizializza le liste di ban
declare -A BAN_CLASSI_16
declare -A BAN_CLASSI_24

# Analizza classi_16_molesti.log
LOG_FILE_16="classi_16_molesti.log"
if [ -f "$LOG_FILE_16" ]; then
  while read -r line; do
    COUNT=$(echo $line | awk '{print $1}')
    IP_CLASS_16=$(echo $line | awk '{print $2"/16"}')
    
    if [ "$COUNT" -gt $MAXCOUNT ]; then
      BAN_CLASSI_16["$IP_CLASS_16"]=1
    fi
  done < "$LOG_FILE_16"
else
  echo "File di log $LOG_FILE_16 non trovato."
  exit 1
fi

# Analizza classi_24_molesti.log
LOG_FILE_24="classi_24_molesti.log"
if [ -f "$LOG_FILE_24" ]; then
  while read -r line; do
    COUNT=$(echo $line | awk '{print $1}')
    IP_CLASS_24=$(echo $line | awk '{print $2}')
    IP_CLASS_16=$(echo $IP_CLASS_24 | awk -F'.' '{print $1"."$2".0.0/16"}')

    # Aggiungi la classe /24 se supera 50 connessioni o se appartiene a una classe /16 da bannare
    if [ "$COUNT" -gt $MAXCOUNT ] || [ -n "${BAN_CLASSI_16["$IP_CLASS_16"]}" ]; then
      BAN_CLASSI_24["$IP_CLASS_24"]=1
    fi
  done < "$LOG_FILE_24"
else
  echo "File di log $LOG_FILE_24 non trovato."
  exit 1
fi

# Effettua i ban per le classi /24 solo se non sono gia presenti in iptables
for IP_CLASS in "${!BAN_CLASSI_24[@]}"; do
  if ! sudo iptables -L -n | grep -q "$IP_CLASS"; then
    BAN_DURATION=$(shuf -i 6-48 -n 1)  # Genera una durata di ban casuale tra 6 e 48 ore
    ./banna.sh "$IP_CLASS/24" "$BAN_DURATION"
  else
    echo "La classe $IP_CLASS/24 già bloccata in iptables..."
  fi
done

