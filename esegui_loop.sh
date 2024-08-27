#!/bin/bash

# Loop infinito
while true; do
    # Esegui il comando
    # Calcola l'ora attuale meno 3 minuti
   TIME_MINUS_THREE=$(date -d "3 minutes ago" +"%H:%M")
   TIME_2=$(date -d "4 minutes ago" +"%H:%M")
   TIME_3=$(date -d "5 minutes ago" +"%H:%M")
   TIME_4=$(date -d "6 minutes ago" +"%H:%M")
   TIME_5=$(date -d "7 minutes ago" +"%H:%M")

   # Stampa l'ora calcolata
   echo "Ora attuale meno 3 minuti: $TIME_MINUS_THREE"

# Il comando che vuoi eseguire
   echo 'Eseguo il comando alle $(date)'
   COMMAND="./bannarem.sh $TIME_MINUS_THREE"
   eval $COMMAND
   
   COMMAND="./bannarem.sh $TIME_2"
   eval $COMMAND

   COMMAND="./bannarem.sh $TIME_3"
   eval $COMMAND

   COMMAND="./bannarem.sh $TIME_4"
   eval $COMMAND

   COMMAND="./bannarem.sh $TIME_5"
   eval $COMMAND

    # Genera un intervallo di tempo casuale tra 7 e 12 minuti
    INTERVAL=$(shuf -i 5-7 -n 1)
    
    # Converti l'intervallo in secondi
    SLEEP_TIME=$((INTERVAL * 60))
    
    # Dormi per il tempo specificato
    sleep $SLEEP_TIME
done

