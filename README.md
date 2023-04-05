<!---(c) pjunyent, EUPL v.1.2 -->
# Kalkun-dockerfile
Kalkunpod is a lightweight OCI container for [Kalkun](https://github.com/kalkun-sms/Kalkun) + gammu-smsd + mariadb.
The image is based on nginx stable for Alpine Linux and php 8.1, and the latest mariadb ubuntu image.

## Quick links
- Mantainer: [pjunyent](https://github.com/pjunyent)
- Github repo: [github.com/pjunyent/kalkun-dockerfile](https://github.com/pjunyent/kalkun-dockerfile)
- Dockerfile kalkun-gammu: [`latest`](https://hub.docker.com/r/junyent/kalkun-gammu/tags)
- Dockerfile kalkun-mariadb: [`latest`](https://hub.docker.com/r/junyent/kalkun-mariadb/tags)

## How to use this dockerfile
The recommend install is with the kalkunpod.yaml file, for use with Podman or Kubectl. It needs to run with root privileges for accessing the GSM modem for gammu-smsd.

Sample podman pod usage (check the .yaml for paths): 
```bash
# podman play kube kalkunpod.yaml
```

A docker-compose script is under development.

If you prefer to run it directly through cli you can do it with a command similar to this one: (substitute podman for docker where necessary)

```bash
# podman run -dt --name kalkun-mariadb -e MYSQL_RANDOM_ROOT_PASSWORD=RANDOM -e MYSQL_DATABASE=kalkun -e MYSQL_USER=kalkun -e MYSQL_PASSWORD=kalkun -v /path/to/mysql-db:/var/lib/mysql:Z docker.io/junyent/kalkun-mariadb && podman run -dt -e TZ=Etc/UTC --device /path/to/ttyUSB0:/dev/ttyUSB0 -p 80:80 --name kalkun-gammu docker.io/junyent/kalkun-gammu
```
## License
The files contained in this repository are licensed under the EUPL v.1.2.
