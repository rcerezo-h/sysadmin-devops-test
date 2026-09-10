# Diagnóstico de la incidencia

## 1. Primera hipótesis y orden de comprobación

Comenzaría mirando el estado de los contenedores, donde vería que la tanto la API como el PostgreSQL están parados. Después revisaría los logs de la base de datos, ya que la API depende de esta.

En los logs se puede ver que pone `No space left on device` por lo que desde la consola haria `df -h` y al ver que / está al 100% miraria con el comando `du` cuales son los directorios que más espacio ocupan. Esto me lleva a la carpeta de backups que pesa 28GB, por lo que terminaria mirando los backups y el servicio que los genera.

## 2. Causa raíz

La causa raíz como tal está en el script de backups, donde la limpieza lleva ya unos meses fallando y por eso los ficheros se han acumulado hasta dejar sin espacio el servidor.

La cadena completa sería:

`fallo de retención de backups → acumulación de backups → disco al 100% → PostgreSQL se queda sin espacio → PostgreSQL se detiene → la API pierde acceso a la base de datos y termina fallando → nginx no puede conectar con la API → usuarios reciben errores 502 y finalmente el servicio deja de funcionar`.

## 3. Pistas falsas

Una de las pistas falsas es el connection refused, que lo da Nginx, pero aquí no está la causa principal del problema, simplemente informa de que no consigue conectar con la API.

Otra seria la API indicando que no puede resolver el nombre `db`, el cual aparece despues y es consecuencia de que la base de datos no está disponible.

También he visto que el proceso gzip ha sido eliminado por la falta de memoria pero como tal no es la causa principal de la caida.

## 4. La línea que no borra nada

El problema está en utilizar `*.sql.gz` sin comillas en el comando find. Antes de ejecutar find, la shell expande ese patrón y lo sustituye por todos los archivos .sql.gz que encuentra en el directorio. Esto provoca que find reciba varios nombres de archivo donde esperaba un único patrón para -name, muestra el error p`aths must precede expression` y la limpieza no se realiza. Por esto, la retención de backups llevaba meses sin funcionar.

## 5. Resolución inmediata

Primero miraria que está ocupando el disco y confirmaría que los backups antiguos son el problema. Con esto, lo que haría sería borrar unicamente aquellos backups que se han verificado que se pueden borrar, principalmente los mas antiguos.

Una vez tenga más espacio, combrobaria de nuevo cuanto espacio hay y revisaria que la base de datos arranca correctamente. Después, comprobaria el estado de la base de datos y sus logs. Luego, laventaría la API y comprobaria `/ready` y en nginx realizaría una peticion para ver que funciona correctamente.

También comprobaría la integridad de la base de datos, ya que PostgreSQL se apagó de forma incorrecta y tuvo que intentar una recuperación.

Por último, los contenedores no volvieron a levantarse automáticamente porque no tenían configurada una política de reinicio. En el Bloque B añadí restart: unless-stopped precisamente para que no volviera a suceder en caso de caída.

## 6. Resolución de fondo

Por relación entre coste y beneficio aplicaría primero estas medidas:

1. Corregir el script de backup y comprobar que la retención realmente elimina los backups antiguos.

2. Añadir monitorización y alertas de espacio en disco, por ejemplo avisando al llegar al 70-80%, para poder actuar varios días antes de quedarse sin espacio.

3. Añadir una política de reinicio a los contenedores y healthchecks para mejorar la recuperación automática ante fallos.

También revisaría periódicamente que los backups no solo se generan, sino que pueden restaurarse correctamente.

## 7. Fallos de monitorización

El primer fallo era que solo se estaba monitorizando el servicio mediante una petición HTTP, y para detectar este problema deberíamos de haber monitorizado el porcentaje de yso del disco y el incremento en el directorio. Con esto podríamos haber visto días antes que el disco iba a llegar a su límite.

El segundo fallo es la forma en la que recibimos la oferta, ya que llegó a un buzón donde habia muchos mensajes sin leer y sin que nadie pudiera revisarlo. Para estos casos es mejor establecer un canal algo más visible y critico donde se avise a un equipo de guardia o a la persona responsable.

Por último diria que el backup termina indicandonose `Deactivated successfully` ya que el script sigue ejecutandose aunque fallen comandos y acaba dando código de salida 0 indicando que está bien cuando realmente no. Esta no sería una fuente fiable en la que basarnos si no estamos seguros de que el script está bien realizado, por lo que es importante indagar más a fondo para comprobar que realmente funciona. Mi versión corregida del script no debería comportarse igual, ya que tiene control de errores y si falla pg_dump o algún paso crítico, el script termina con un código distinto de 0 y systemd puede marcar la ejecución como fallida en lugar de mostrar `Deactivated successfully`.