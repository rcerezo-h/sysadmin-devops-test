# Hardening del servidor

El entorno utilizado es Ubuntu 24.04 LTS en una máquina virtual local. La VM no tiene una IP pública pero la configuración se ha realizado asumiendo que el servidor estuviera expuesto a Internet.

## Usuario administrativo

Se crea un usuario administrativo separado y se le concede acceso a `sudo`:

```bash
sudo adduser sysadmin
sudo usermod -aG sudo sysadmin
groups sysadmin
```

Se utiliza una cuenta de administración en lugar de acceder directamente como `root`, permitiendonos elevar privilegios únicamente cuando sea necesario.

## Acceso SSH mediante clave

La clave pública del administrador se instala para el usuario `sysadmin`:

```bash
sudo mkdir -p /home/sysadmin/.ssh
sudo cp ~/.ssh/id_ed25519.pub /home/sysadmin/.ssh/authorized_keys
sudo chown -R sysadmin:sysadmin /home/sysadmin/.ssh
sudo chmod 700 /home/sysadmin/.ssh
sudo chmod 600 /home/sysadmin/.ssh/authorized_keys
```

Comprobamos el acceso antes de deshabilitar la autenticación mediante contraseña:

```bash
ssh sysadmin@<IP_SERVIDOR>
```

Se crea `/etc/ssh/sshd_config.d/99-hardening.conf` con:

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

La configuración se valida antes de recargar SSH:

```bash
sudo sshd -t
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication'
sudo systemctl reload ssh
```

Mantenemos el puerto TCP/22, ya que si lo Cambiaramos reduciriamos principalmente el ruido generado por escaneos automatizados, pero no es como tal una medida significativa de autenticación. Priorizamos deshabilitar `root`, eliminar el acceso mediante contraseña y exigir clave pública.

## Firewall

Utilizamos UFW por ser la herramienta de firewall integrada y sencilla de administrar en Ubuntu.

Se aplica una política restrictiva para conexiones entrantes y permisiva para tráfico saliente:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status verbose
```

Solo se permite inicialmente SSH. Los puertos de los servicios de aplicación se abrirán únicamente cuando sean necesarios.

## Actualizaciones

Se actualiza el índice de paquetes y el sistema:

```bash
sudo apt update
sudo apt upgrade -y
```

Se comprueba que las actualizaciones automáticas de seguridad estén instaladas y activas:

```bash
dpkg -l | grep unattended-upgrades
sudo systemctl status unattended-upgrades --no-pager
```

Se mantienen activadas las actualizaciones automáticas de seguridad para reducir el tiempo de exposición a vulnerabilidades conocidas.

## Fail2ban

No pienso que sea necesario instalar `fail2ban`, ya que estar deshabilitada la autenticación SSH mediante contraseña, los ataques de fuerza bruta contra credenciales dejan de ser una amenaza relevante en este escenario. Podríamos añadirlo posteriormente para reducir intentos abusivos, ruido de logs o proteger otros servicios expuestos.
