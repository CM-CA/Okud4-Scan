# Oukd4-Scan.
autoscaner para web pentesting.

## Opciones.

Permite escanear tanto una direccion ip como una URL (http y https) para automatizar la busqueda de directorios y subdominios,
asi como comprobar si dicha web es vulnerable a LFI o RFI.

Antes de ejecutarse cualquier escaner, se creara un directorio de trabajo que toma como nombre la ip, luego se crearan los distintos subdominios en donde
se guardara toda la informacion obtenida para poder analizarla.

El usuario puede usar el diccionario por defecto o introducir la ruta del suyo propio para comprobar la vulnerabilidad RFI o LFI.

## Instalacion.

El script debe tener permiso de ejecución: 
`chmod +x ./autoscan.sh`

Para ejecutarlo simplemente debe escribir:
`./autoscan.sh`

