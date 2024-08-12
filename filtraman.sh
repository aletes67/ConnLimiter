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
giorno_corrente="Aug  11"

# Filtra le righe del log nell'intervallo di tempo specificato
awk -vstart="$ora_inizio" -vend="$ora_fine" '$0 ~ start {p=1} $0 ~ end {e=1} e && $0 !~ end {p=0} p' /var/log/haproxy.log | grep -Ev "$ignoreregex"
