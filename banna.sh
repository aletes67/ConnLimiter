#!/bin/bash

# Verifica se sono stati forniti due parametri
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 classe_ip num_ore"
    exit 1
fi

# Parametri di input
classe_ip=$1
num_ore=$2

# Rimuovi il .0 finale per controllare contro la lista di IP da ignorare
classe_ip_no_dot_zero=$(echo $classe_ip | sed 's/\.0\/24//')
classe_ip_no_24=$(echo $classe_ip | sed 's/\/24//')

# Verifica se l'IP senza .0 nella lista di esclusione
if grep -q "^$classe_ip_no_dot_zero" /etc/ddos/ignore.ip.list; then
    echo "L'IP $classe_ip_no_dot_zero e in lista di esclusione. Nessuna azione eseguita."
    exit 0
fi


# Funzione per estrarre il netname, organization e l'email di abuse
extract_info() {
    local whois_output="$1"

    # Estrai l'organizzazione, se disponibile
    local organization=$(echo "$whois_output" | grep -iE "(organization:|CustName:)" | awk -F': ' '{print $2}' | head -n 1)

    # Se l'organizzazione non disponibile, estrai il netname
    if [ -z "$organization" ]; then
        organization=$(echo "$whois_output" | grep -iE "(netname:)" | awk -F': ' '{print $2}' | head -n 1)
    fi

    # Estrai le email di contatto abuse (sia "Abuse contact" sia "OrgAbuseEmail" sia linee con "abuse")
    local abuse_email=$(echo "$whois_output" | grep -iE "(Abuse contact|OrgAbuseEmail:|abuse)" | grep -Eo "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")

    echo "$organization" "$abuse_email"
}

# Esegui il comando whois sull'IP
whois_output=$(whois $classe_ip_no_24)

# Estrai le informazioni
read organization abuse_email <<< $(extract_info "$whois_output")

# Se organization e abuse_email non sono valorizzati, prova con l'opzione -B
if [ -z "$organization" ] && [ -z "$abuse_email" ]; then
    whois_output=$(whois -B $classe_ip_no_24)
    read organization abuse_email <<< $(extract_info "$whois_output")
fi


# Esegui il blocco dell'IP con iptables
sudo iptables -I INPUT 1 -s $classe_ip -j DROP
echo "$(date '+%Y-%m-%d %H:%M:%S') - Blocco della classe IP $classe_ip eseguito con successo. Provider: $organization, Email abuse: $abuse_email."

# Calcola l'orario in cui il blocco sara rimosso
unban_time=$(date -d "+$num_ore hours" +"%Y-%m-%d %H:%M:%S")

# Scrivi l'IP bannato e l'ora di rimozione nel file di log
log_file="./ip_ban.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Classe IP $classe_ip bannata. Rimozione prevista per: $unban_time. Provider: $organization, Email abuse: $abuse_email" | sudo tee -a $log_file

# Pianifica la rimozione del blocco con at
echo "sudo iptables -D INPUT -s $classe_ip -j DROP" | at now + $num_ore hours
echo "Il blocco sara rimosso automaticamente tra $num_ore ore."

