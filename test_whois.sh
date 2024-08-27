#!/bin/bash

# Verifica se fornito un parametro
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 ip_classe_24"
    exit 1
fi

# Parametro di input
ip_classe=$1

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
whois_output=$(whois $ip_classe)

# Estrai le informazioni
read organization abuse_email <<< $(extract_info "$whois_output")

# Se organization e abuse_email non sono valorizzati, prova con l'opzione -B
if [ -z "$organization" ] && [ -z "$abuse_email" ]; then
    whois_output=$(whois -B $ip_classe)
    read organization abuse_email <<< $(extract_info "$whois_output")
fi

# Mostra i risultati
echo "IP Classe: $ip_classe"
echo "Organization/Netname: $organization"
echo "Abuse Email: $abuse_email"

