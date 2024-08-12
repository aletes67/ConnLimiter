#!/bin/bash

# Definizione dei pattern da ignorare
ignoreregex="\/images\/.*|.*\/assets\/.*|.*\/css\/.*|.*\/js\/.*|.*\/fonts\/.*|.*favicon.*|.*captcha.*|.*bk_admin.*|.*admin\.lulop\.com.*|.*lulopsecurephpmyadmin.*|.*\/track\/pixel\/.*|.*Pingdom.*|.*newsletter.*|.*\/proxy\/.*|.*log\/preview.*|.*\/Footer.*|.*log\/download\/.*|.*apple-touch.*|.*asyncjs.php.*|.*adserver\.lulop\.com.*|.*handshake failure.*|.*cron.*"

# Verifica se sono stati forniti due parametri
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 ora_inizio ora_fine (esempio: $0 12:00 12:05 oppure $0 15:00 17:00)"
    exit 1
fi

# Parametri di input
ora_inizio=$1
ora_fine=$2

# Ottieni il giorno corrente
giorno_corrente=$(date +"%b %e")
#giorno_corrente="Aug  7"

# Filtra le righe del log nell'intervallo di tempo specificato
awk -v start="$giorno_corrente $ora_inizio" -v end="$giorno_corrente $ora_fine" '$0 >= start && $0 <= end' /var/log/haproxy.log | grep -Ev "$ignoreregex" > filtered_logs.log

# Estrazione degli IP, ignorando il timestamp
awk '{print $6}' filtered_logs.log > ip_time.log

# Conteggio delle richieste per IP, ignorando il timestamp
awk '{print $1}' ip_time.log | sort | uniq -c | sort -nr > ip_molesti.log

# Raggruppare gli IP per classi /24 e sommare le richieste
awk -F. '{print $1"."$2"."$3".0"}' ip_time.log | sort | uniq -c | sort -nr > classi_24_molesti.log

awk -F. '{print $1"."$2".0.0"}' ip_time.log | sort | uniq -c | sort -nr > classi_16_molesti.log
