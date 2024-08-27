#!/bin/bash
###DI Alessandro Testa contatto@alessandrotesta.info

LOCKFILE="script_lock_file"
LOCKFD=99
SCRIPT_TIMEOUT=35  # Timeout globale per l'intero script (in secondi)

# Funzione per rimuovere il file di lock in caso di uscita dello script
cleanup() {
  rm -f "$LOCKFILE"
}

# Funzione per ottenere il lock
lock() {
  eval "exec $LOCKFD>$LOCKFILE"
  flock -n $LOCKFD && return 0 || return 1
}

# Verifica se lo script \Uffffffffn esecuzione e ottieni il lock
if ! lock; then
  echo "Lo script \Uffffffffn esecuzione."
  exit 1
fi

# Assicurati che il file di lock venga rimosso alla fine
trap cleanup EXIT

# Inserisci il PID corrente nel file di lock
echo $$ > "$LOCKFILE"

# Imposta un timeout globale per l'intero script
timeout $SCRIPT_TIMEOUT bash << 'END_SCRIPT'
# Il resto del tuo script inizia qui

if [ -z "$1" ]; then
  TIME=$(date +"%H:%M")
else
  TIME="$1"
fi

cd /home/ubuntu || { echo "Errore: impossibile cambiare directory in /home/ubuntu"; exit 1; }
MAXCOUNT=30
MAX_CONN=150
log_file="./ip_ban.log"

CURRENT_TIME=$(date +"%H:%M:%S")
TIME_MINUS_TWO=$(date -d "$CURRENT_TIME today - 1 minutes" +"%H:%M:%S")
TIME_PLUS_ONE=$(date -d "$CURRENT_TIME today + 1 minute" +"%H:%M:%S")

echo "TIME: $TIME_MINUS_TWO $CURRENT_TIME"

./filtra.sh "$TIME_MINUS_TWO" "$CURRENT_TIME"

if [ $? -ne 0 ]; then
  echo "filtra.sh ha incontrato un errore."
  exit 1
fi

LOG_FILE_16="classi_16_molesti.log"
LOG_FILE_24="classi_24_molesti.log"

if [ -f "$LOG_FILE_16" ]; then
  conn_countold=$(awk '{sum += $1} END {print sum}' "$LOG_FILE_16")
else
  echo "File di log $LOG_FILE_16 non trovato."
  exit 1
fi

conn_count=$(sudo netstat -ntu | grep ESTABLISHED | grep -wv "212.39" | grep -wv "172.31.3" | wc -l)

#conn_count=160
echo "conn_count: $conn_count"

if ! [[ "$conn_count" =~ ^[0-9]+$ ]]; then
  echo "Errore: conn_count non \Uffffffffn numero valido: $conn_count"
  exit 1
fi

if [ "$conn_count" -gt "$MAX_CONN" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') -- Numero di connessioni attive ($conn_count) superiore al limite ($MAX_CONN). Eseguo il riavvio del servizio Apache..." >> "$log_file"

  # Esegui il riavvio di Apache con timeout e gestisci eventuali errori
  timeout 30 ssh -i key-lulop.pem ubuntu@172.31.3.217 'sudo service apache2 restart'
  SSH_EXIT_CODE=$?

  if [ $SSH_EXIT_CODE -eq 0 ];then
    echo "$(date '+%Y-%m-%d %H:%M:%S') -- Riavvio Apache completato." >> "$log_file"
    
    # Chiudi le connessioni per tutte le classi /16 con pi\Uffffffff1 connessione
    while read -r line; do
      COUNT=$(echo $line | awk '{print $1}')
      IP_CLASS_16=$(echo $line | awk '{print $2"/16"}')

      if [ "$COUNT" -gt 1 ]; then
        echo "Chiudo le connessioni per la classe /16: $IP_CLASS_16"
        sudo iptables -I INPUT -s "$IP_CLASS_16" -j REJECT --reject-with tcp-reset
      fi
    done < "$LOG_FILE_16"
    
    # Dopo aver chiuso le connessioni, rimuovi le regole per evitare il blocco permanente
    while read -r line; do
      IP_CLASS_16=$(echo $line | awk '{print $2"/16"}')
      sudo iptables -D INPUT -s "$IP_CLASS_16" -j REJECT --reject-with tcp-reset
    done < "$LOG_FILE_16"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') -- Chiusura conn ripetute completato." >> "$log_file"
    
    # Secondo ciclo: Identifica e banna le sequenze di classi /16
    echo "Inizio il secondo ciclo per identificare le sequenze di classi /16."

    # Ordina la lista delle classi /16 per il secondo ottetto
    sorted_list=$(sort -t'.' -k2,2n "$LOG_FILE_16")

    previous_class=""
    sequence_count=0
    sequence_classes=()

    while read -r line; do
      current_class=$(echo "$line" | awk '{print $2}')
      current_octet=$(echo "$current_class" | awk -F'.' '{print $2}')
      echo "Processing class: $current_class (ottetto: $current_octet)"

      if [ -n "$previous_class" ] && [ $(echo "$current_octet - $previous_octet" | bc) -eq 1 ]; then
        sequence_count=$((sequence_count + 1))
        sequence_classes+=("$current_class")
        echo "Aggiungo alla sequenza: $current_class (sequence_count: $sequence_count)"
      else
        if [ $sequence_count -ge 3 ]; then
          echo "Trovata sequenza valida: ${sequence_classes[@]}"
          for class_info in "${sequence_classes[@]}"; do
            IP_CLASS="$class_info/16"
            COUNT=$(echo "$line" | awk '{print $1}')

            if ! sudo iptables -L -n | grep -q "$IP_CLASS"; then
              if [ "$log_written" = false ]; then
                echo -e "\n\n################################  $(date '+%Y-%m-%d %H:%M:%S') - Inizio ban classi /16" >> "$log_file"
                log_written=true
              fi
              echo "Banno la classe /16: $IP_CLASS (durata: $(shuf -i 6-26 -n 1))"
              BAN_DURATION=$(shuf -i 6-26 -n 1)
              ./banna.sh "$IP_CLASS" "$BAN_DURATION" "$COUNT"
            fi
          done
        else
          echo "Sequenza troppo corta, non viene bannata."
        fi
        sequence_count=1
        sequence_classes=("$current_class")
      fi

      previous_class="$current_class"
      previous_octet="$current_octet"
    done <<< "$sorted_list"

    # Gestisci l'ultima sequenza trovata
    if [ $sequence_count -ge 3 ]; then
      echo "Trovata sequenza valida alla fine: ${sequence_classes[@]}"
      for class_info in "${sequence_classes[@]}"; do
        IP_CLASS="$class_info/16"
        COUNT=$(echo "$line" | awk '{print $1}')
        if [ "$log_written" = false ]; then
           echo -e "\n\n################################  $(date '+%Y-%m-%d %H:%M:%S') - Inizio ban classi /16" >> "$log_file"
           log_written=true
        fi
        echo "Banno la classe /16: $IP_CLASS (durata: $(shuf -i 6-26 -n 1))"
        BAN_DURATION=$(shuf -i 6-26 -n 1)
        ./banna.sh "$IP_CLASS" "$BAN_DURATION" "$COUNT"
      done
    else
      echo "Nessuna sequenza valida trovata alla fine."
    fi

  else
    echo "Errore durante il riavvio di Apache o timeout scaduto." >> "$log_file"
    exit 1
  fi
else
  echo "Numero di connessioni attive non supera il limite. Nessuna azione necessaria."
fi
END_SCRIPT

# Rimuovi il file di lock dopo l'esecuzione dello script
cleanup

