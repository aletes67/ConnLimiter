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

# Verifica se l'IP senza .0 \Uffffffffella lista di esclusione
if grep -q "^$classe_ip_no_dot_zero" /etc/ddos/ignore.ip.list; then
    echo "L'IP $classe_ip_no_dot_zero \Uffffffffn lista di esclusione. Nessuna a
zione eseguita."
    exit 0
fi

# Ottieni le informazioni del provider e l'email abuse usando whois
whois_info=$(whois $classe_ip_no_24)
provider_name=$(echo "$whois_info" | grep -i 'OrgName:' | head -n 1 | awk -F: '{
print $2}' | xargs)
abuse_email=$(echo "$whois_info" | grep -i 'OrgAbuseEmail:\|abuse-mailbox' | hea
d -n 1 | awk -F: '{print $2}' | xargs)

# Esegui il blocco dell'IP con iptables
sudo iptables -I INPUT 1 -s $classe_ip -j DROP
echo "$(date '+%Y-%m-%d %H:%M:%S') - Blocco della classe IP $classe_ip eseguito 
con successo. Provider: $provider_name, Email abuse: $abuse_email."

# Calcola l'orario in cui il blocco sar\Uffffffffimosso
unban_time=$(date -d "+$num_ore hours" +"%Y-%m-%d %H:%M:%S")

# Scrivi l'IP bannato e l'ora di rimozione nel file di log
log_file="./ip_ban.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Classe IP $classe_ip bannata. Rimozione pre
vista per: $unban_time. Provider: $provider_name, Email abuse: $abuse_email" | s
udo tee -a $log_file

# Pianifica la rimozione del blocco con at
echo "sudo iptables -D INPUT -s $classe_ip -j DROP" | at now + $num_ore hours
echo "Il blocco sara rimosso automaticamente tra $num_ore ore."
