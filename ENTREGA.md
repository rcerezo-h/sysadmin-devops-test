# Entrega — prueba técnica

> Este es el documento que leemos primero. Rellénalo a medida que avanzas, no al
> final con prisa.
>
> Borra estas instrucciones y las de cada sección cuando las hayas leído.
>
> **Sé breve.** Preferimos tres frases precisas a tres párrafos. Y **si no has hecho
> algo, dilo** — un "no llegué al Bloque E por tiempo" es una respuesta válida y
> profesional; dejar el hueco en blanco no.
>
> Rellenar este documento debería llevarte unos **15 minutos**, no media hora.
> Las secciones marcadas **(opcional)** solo hace falta rellenarlas si
> implementaste esa parte — no las dejes en blanco por vergüenza, simplemente
> bórralas si no aplican.

---

## 0. Resumen

- **Bloques completados:** A / B / C / D o E / F →
- **Tiempo aproximado dedicado:**
- **Qué he dejado fuera y por qué:**
- **De lo que he entregado, lo que menos me convence:**

> Esa última línea la preguntamos en serio. Nadie entrega algo perfecto en 3 horas.
> Saber dónde están las costuras de tu propio trabajo es una señal muy buena.

## 1. Suposiciones que he tenido que hacer

> Todo lo que el enunciado dejaba ambiguo y has resuelto tú por tu cuenta.

-

## 2. Entorno

- **Qué usé como entorno Linux (WSL2 / VM local / VM cloud) y por qué:**
Use una VM local, la cual me permite trabajar con un sistema linux completo con systemd y modificar SSH, firewall, y servicios sin depender de una infra cloud.
- **Distro y versión:**
Ubuntu 24.04.4 LTS (Noble Numbat)
- **¿Tenía IP pública real, o lo tratasteis como hipotético?:**
Lo traté como hipotético, ya que no tenia IP pública real. Aun así, he trabajado como si estuviera expuesto a Internet para definir las políticas de seguridad.
- **Versiones de Docker / Compose / Terraform / kind, según lo que hayas usado:**
Docker 29.4.2 
Docker Compose v5.1.3.

---

## Bloque A — Tu entorno Linux


### A.1 y A.2 — Hardening y reproducibilidad

**Qué he hecho:**
He creado un usuario administrativo sysadmin con sudo, configurado acceso SSH exclusivamente mediante clave pública, también he deshabilitado el acceso remoto de root y la autenticación mediante contraseña. Además, he configurado UFW con política deny incoming / allow outgoing y mantenido activas las actualizaciones automáticas de seguridad.

**Decisiones y su motivo** (SSH, firewall, política de actualizaciones):
Se mantiene SSH en el puerto 22, ya que cambiarlo reduce principalmente ruido de escaneos pero no sustituye controles de autenticación como tal. Utilizo UFW por su integración y facilidad en Ubuntu, abriendo únicamente los servicios necesarios. Por último, mantengo activo unattended-upgrades para aplicar automáticamente todas las actualizaciones de seguridad necesarias.

**Sobre `fail2ban`** — no lo he instalado, porque:
Considero que al haber quitado la autenticacion de contraseña en SSH, fail2ban no sería de gran aportación frente ataques de fuerza bruta. Lo tendría más en cuenta si hubiera más servicios autenticados expuestos o en caso de querer reducir intentos abusivos o el ruido en los logs.

**Cómo se reproduce todo esto:**
Documentado paso a paso en [`docs/hardening.md`](docs/hardening.md).


### A.3 — El script de backup

**Fallo 1 — el destructivo:** ¿cuál es, y qué pasa exactamente cuando se dispara?
La limpieza con rm -rf $BACKUP_DIR/tmp/* construía una ruta usando una variable que no tenia ningún tipo de protección. Si BACKUP_DIR estuviese vacía o tuviera un valor erroneo, podría pasar que se eliminara contenido fuera del directorio de backups. Lo que he hecho ha sido cambiarlo por una limpieza que afecte unicamente al fichero temporal de la ejecución.

**Fallo 2 — el que no borra nunca nada:** ¿cuál es, y el mecanismo exacto por el que falla?
El *.sql.gz del find no estaba entre comillas, lo que podía hacer que la teminal (shell), lo interpretara antes de interpretar el find, haciendo que el comando no funcione y que la limpieza fallase sin que el script diera error.

**Los demás cambios:**
He añadido manejo de errores, añadido comillas a las variables, que el directorio no se vuelva a crear si ya existe, nombres de backup con su respectiva fecha, generación mediante fichero temporal y eliminación segura de backups antiguos. Cabe destacar que el script pasa shellcheck sin avisos.

**Dónde he puesto las credenciales, y por qué ahí:**
La contraseña se ha eliminado del script y la he almacenado en ~/.pgpass con permisos 600. De esta forma no se versionan credenciales en Git y se utiliza el mecanismo de autenticación soportado por PostgreSQL.

### A.4 — Ejecución programada

**systemd timer vs cron:**
Al final he optado por un timer de systemd porque se integra con el control de estado y los logs de journald, y Persistent=true permite recuperar una ejecución que se haya perdido mientras la máquina estaba apagada. Esto con cron como tal no se podría hacer ya que si el servidor esta apagado, cron no va a ejecutar nada. Si buscasemos una alternativa que ejecuta aunque esté apagado usaría anacron, la cual lo ejecuta cuando el servidor vuelve a estar operativo.

### A.5 — Detección de fallos

**Qué he montado:**
Si el backup falla, el script termina indicando que ha habido un error. systemd guarda lo que ha ocurrido y los mensajes del script en sus registros, por lo que podemos revisar fácilmente si la tarea terminó bien o falló.

Para comprobar el estado se puede usar:

```bash
systemctl status inventario-backup.service
```

Y para ver los mensajes y errores de la ejecución:

```bash
journalctl -u inventario-backup.service
```


**Cómo verificaría que un backup se restaura de verdad:**
Lo que haría sería restaurar de forma periódica el dump que se genere y comprobaría que la importación acaba sin errores, validando las tablas y los datos más relevantes que tengamos en la base de datos con diferentes queries.

### Evidencias del bloque A
```
rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  sudo ufw status verbose
Estado: activo
Acceso: on (low)
Predeterminado: deny (entrantes), allow (salientes), deny (enrutados)
Perfiles nuevos: skip

Hasta                      Acción      Desde
-----                      ------      -----
22/tcp (OpenSSH)           ALLOW IN    Anywhere                  
22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)  


rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no

rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  shellcheck scripts/backup-db.sh
 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  


 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  systemctl status inventario-backup.timer --no-pager
● inventario-backup.timer - Ejecución diaria del backup de inventario
     Loaded: loaded (/etc/systemd/system/inventario-backup.timer; enabled; preset: enabled)
     Active: active (waiting) since Thu 2026-09-10 19:47:52 CEST; 22min ago
    Trigger: Fri 2026-09-11 03:00:00 CEST; 6h left
   Triggers: ● inventario-backup.service

sep 10 19:47:52 Ubuntu-rcerezo-h systemd[1]: Started inventario-backup.timer - Ejecución diaria del backup de inventario.

 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  journalctl -u inventario-backup.service -n 20 --no-pager
sep 10 19:47:03 Ubuntu-rcerezo-h systemd[1]: Starting inventario-backup.service - Backup diario de la base de datos de inventario...
sep 10 19:47:03 Ubuntu-rcerezo-h backup-db.sh[9750]: [2026-09-10 19:47:03] Iniciando backup en /var/backups/inventario/inventario-2026-09-10_19-47-03.sql.gz
sep 10 19:47:04 Ubuntu-rcerezo-h backup-db.sh[9750]: [2026-09-10 19:47:04] Limpiando backups de más de 7 días
sep 10 19:47:04 Ubuntu-rcerezo-h backup-db.sh[9750]: [2026-09-10 19:47:04] Backup completado correctamente: /var/backups/inventario/inventario-2026-09-10_19-47-03.sql.gz
sep 10 19:47:04 Ubuntu-rcerezo-h systemd[1]: inventario-backup.service: Deactivated successfully.
sep 10 19:47:04 Ubuntu-rcerezo-h systemd[1]: Finished inventario-backup.service - Backup diario de la base de datos de inventario.

 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  ls -lh /var/backups/inventario
total 8,0K
-rw------- 1 rcerezo-h rcerezo-h 447 sep 10 19:39 inventario-2026-09-10_19-39-12.sql.gz
-rw------- 1 rcerezo-h rcerezo-h 448 sep 10 19:47 inventario-2026-09-10_19-47-03.sql.gz
 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test   dev-tech ±  
```

---

## Bloque B — Docker y Docker Compose

### B.1 — Dockerfile

**Cambios, agrupados por motivo:**
He cambiado python:latest por una imagen python:3.12-slim ya que es buena práctica tener una versión fija más que la latest. También he eliminado paquetes innecesarios y separado la copia de requirements.txt del resto del código para aprovechar mejor la caché de Docker. Por último, he eliminado las credenciales del Dockerfile, creado un usuario sin privilegios para ejecutar la aplicación y cambiado el arranque de Flask por Gunicorn.

**Tamaño de imagen antes / después (opcional):**

```
 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  docker images inventario-api         
                                                                                                                                          i Info →   U  In Use
IMAGE                 ID             DISK USAGE   CONTENT SIZE   EXTRA
inventario-api:test   52971e9bed98        215MB         52.9MB        

```

### B.2 — Compose

**Cambios y su motivo:**
He fijado versiones de las imágenes concretas, añadido persistencia para la base de datos, eliminado la exposición directa de los puertos 5432 y 8080, movido las credenciales a variables de entorno y añadido healthchecks y políticas de reinicio. Lo único que queda expuesto por el puerto 80 es nginx.

**Las dos líneas problemáticas del servicio `proxy`:** ¿cuáles, y qué permite cada una?
`/var/run/docker.sock:/var/run/docker.sock` daba al contenedor acceso al socket de Docker del host, lo que puede hacer que otras personas puedan controlar otros contenedores y escalar privilegios sobre la máquina. El otro es `privileged`: true, el cual otorgaba al contenedor privilegios excesivos que para nginx no es necesario.

**`depends_on`:** qué no hace, y qué he puesto para conseguir el efecto que se buscaba:
Por sí solo controla el orden de arranque, pero no espera a que un servicio esté realmente listo, por lo que he añadido healthchecks y `condition: service_healthy` para que la API espere a PostgreSQL y el proxy espere a que la API responda correctamente en /ready.

**Lo que he decidido NO arreglar, y por qué:**
No he llegado a tocar nada relacionado con la CPU ni la memoria porque no tengo métricas reales del consumo que se produce, por lo que no puedo dimensionarlo bien. Podría hacerlo, pero sería sin fundamento y podría limitar el correcto funcionamiento.

### B.3 — Evidencia de funcionamiento

> Un `curl` que cree un equipo y otro que lo lea de vuelta, con sus salidas.

```
rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  curl -i http://localhost/health
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Thu, 10 Sep 2026 19:00:57 GMT
Content-Type: application/json
Content-Length: 16
Connection: keep-alive

{"status":"ok"}

 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  curl -i http://localhost/ready
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Thu, 10 Sep 2026 19:01:03 GMT
Content-Type: application/json
Content-Length: 19
Connection: keep-alive

{"status":"ready"}

 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  curl -i -X POST http://localhost/equipos \
  -H "Content-Type: application/json" \
  -d '{"hostname":"pc-malaga-01","so":"Ubuntu 24.04","ubicacion":"Malaga"}'
HTTP/1.1 201 CREATED
Server: nginx/1.27.5
Date: Thu, 10 Sep 2026 19:02:43 GMT
Content-Type: application/json
Content-Length: 9
Connection: keep-alive

{"id":1}

 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  curl -i http://localhost/equipos
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Thu, 10 Sep 2026 19:02:56 GMT
Content-Type: application/json
Content-Length: 78
Connection: keep-alive

[{"hostname":"pc-malaga-01","id":1,"so":"Ubuntu 24.04","ubicacion":"Malaga"}]

```
Abrí el puerto 80 para que nginx sea lo unico accesible desde fuera de la máquina
```
rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  sudo ufw status
[sudo] contraseña para rcerezo-h: 
Estado: activo

Hasta                      Acción      Desde
-----                      ------      -----
OpenSSH                    ALLOW       Anywhere                  
80/tcp                     ALLOW       Anywhere                  
OpenSSH (v6)               ALLOW       Anywhere (v6)             
80/tcp (v6)                ALLOW       Anywhere (v6)             
```
También comprobé la persistencia
```
 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  docker compose down
[+] down 4/4
 ✔ Container compose-proxy-1 Removed                                                                                                                      0.3s
 ✔ Container compose-api-1   Removed                                                                                                                      0.5s
 ✔ Container compose-db-1    Removed                                                                                                                      0.3s
 ✔ Network compose_default   Removed                                                                                                                      0.1s
 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  docker compose up -d
[+] up 4/4
 ✔ Network compose_default   Created                                                                                                                      0.1s
 ✔ Container compose-db-1    Healthy                                                                                                                      6.3s
 ✔ Container compose-api-1   Healthy                                                                                                                     16.9s
 ✔ Container compose-proxy-1 Started                                                                                                                     17.2s

 rcerezo-h@Ubuntu-rcerezo-h  ~/sysadmin-devops-test/compose   dev-tech ±  curl -i http://localhost/equipos
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Thu, 10 Sep 2026 19:08:27 GMT
Content-Type: application/json
Content-Length: 78
Connection: keep-alive

[{"hostname":"pc-malaga-01","id":1,"so":"Ubuntu 24.04","ubicacion":"Malaga"}]

```
---

## Bloque C — CI con GitHub Actions

**Enlace a una ejecución en verde:**
https://github.com/rcerezo-h/sysadmin-devops-test/actions/runs/34520107096

**Estrategia de etiquetado de imágenes, y su motivo:**
Cada imagen Docker se guarda usando el identificador del commit (github.sha). De esta forma puedo saber exactamente con qué versión del código se creó cada imagen y si una nueva versión da problemas, puedo volver a una anterior.

**Diferencia de comportamiento entre `push` y `pull_request`, y por qué:**
En ambos casos la pipeline valida los scripts, el Dockerfile, el Docker Compose y construye la imagen. La diferencia está en que cuando se hace un push se publica la imagen en GHCR, mientras que en una Pull Request únicamente se comprueba que los cambios funcionan correctamente antes de integrarlos.

**Cómo he fijado las versiones de las acciones de terceros, y qué riesgo evita:**
He indicado versiones concretas de las acciones que utiliza la pipeline, por ejemplo actions/checkout@v4 y hadolint/hadolint-action@v3.1.0. Si estuviera en un entorno más estricto las fijaría directamente a un commit SHA, para asegurar que siempre se ejecuta exactamente el mismo código aunque una etiqueta cambie en el futuro.

**Si no he podido publicar en GHCR:** qué falla exactamente y qué haría en el repo original:
El workflow ha terminado sin problemas correctamente y la imagen se ha podido publicar.

### C.3 — El despliegue que no está

**Mecanismo elegido y por qué:**
Añadiría un job al final de la pipeline que se conectase al servidor mediante SSH y ejecutase Docker Compose para descargar y levantar la nueva imagen

**Gestión de credenciales:**
Las credenciales las gestionaría a través de GitHub Secrets y nunca desde el repositorio directamente. También, limitaría los permisos para que solamente se puedan usar durante el despliegue.

**Problema de guardar una clave SSH en Secrets y mitigación:**
Como tal guardar una clave SSH en Secrets funciona, pero si este se ve comprometido alguien la podría usar para entrar al servidor. Para mitigar esto lo que se podría hacer es usar una clave exclusiva para CI/CD, con los permisos justos y rotaría de forma periódica la clave.

---

## Bloque D — Terraform

> Elige D **o** E. Borra la sección del que no hayas hecho. Lo obligatorio son las
> tres primeras preguntas; el código y las dos últimas preguntas son opcionales.

### Preguntas (obligatorio)

1. **El estado** — qué es, qué pasa si se pierde, y qué pasa con dos `apply` simultáneos en local:
2. **Terraform vs Ansible** — qué resuelve cada uno; ¿el Bloque A con Terraform? ¿este con Ansible?
3. **El secreto en el estado** — ¿es cierto que la contraseña acaba ahí en claro?, y qué implica:

### Si implementaste el código (opcional)

**Estructura de lo que he escrito:**

**Cómo he gestionado la contraseña de la base de datos:**

**Qué pasó con el volumen y los datos tras `destroy`:**

**Salida resumida de `plan` / `apply`:**

```
```

4. **(Opcional) Backend remoto** — dónde lo pondría para un equipo pequeño, y el bloqueo:
5. **(Opcional) `terraform destroy` en producción** — al menos un mecanismo para evitarlo:

---

## Bloque E — Kubernetes

> Elige D **o** E. Borra la sección del que no hayas hecho. Lo obligatorio son las
> tres primeras preguntas; los manifiestos y las dos últimas preguntas son
> opcionales.

### Preguntas (obligatorio)

1. **`livenessProbe` vs `readinessProbe`** — diferencia, y qué pasa si las intercambias:
2. **Secrets** — ¿están cifrados?, quién puede leerlos, y una alternativa real:
3. **¿Merece la pena K8s para una organización así?** — respuesta honesta, y cuándo cambiaría:

### Si implementaste los manifiestos (opcional)

**Estructura de los manifiestos:**

**Qué he usado para exponer la aplicación, y qué implica:**

**`kubectl get all -n <namespace>`:**

```
```

**Evidencia del rolling update:**

```
```

4. **(Opcional) Estado** — por qué la base de datos no va normalmente en un `Deployment`:
5. **(Opcional) `requests` vs `limits`** — qué hace cada uno, y superar el límite de memoria frente a superar el de CPU:

---

## Bloque F — Incidencia

**Enlace a tu análisis:** [docs/incidencia.md](docs/incidencia.md)

---

## Notas finales

> Espacio libre. Lo que quieras contarnos: algo que te ha llamado la atención, una
> decisión de la que quieres dar contexto, algo que harías distinto con más tiempo,
> o una crítica al propio enunciado. Todo eso se lee.
