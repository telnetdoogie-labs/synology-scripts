# Update Docker Compose Version

[update_docker_compose.sh](./update_docker_compose.sh)

This script can be used to update your Synology version of `docker-compose` to the latest version.

This script must be run as `root` or via `sudo`

### Downloading

- ssh into the synology as a user with `sudo` rights
- download the script:

```
sudo wget -O update_docker_compose.sh https://raw.githubusercontent.com/telnetdoogie-labs/synology-scripts/main/update_docker_compose.sh
```

- Make it executable:

```
sudo chmod +x update_docker_compose.sh
```

### Usage

To run the script:

```
sudo ./update_docker_compose.sh
```

This will check the running version of `docker-compose` on the host and, if there is a different version available, will backup the current version to `docker-compose.{version}` and download the latest version to replace the default verion.

**Typical Output:**

```
Current version of docker-compose: v2.9.0-6413-g38f6acd
Latest version of docker-compose: v2.18.1


Installing latest version of docker-compose...
Backing up current version of docker-compose...
  creating backup << /var/packages/ContainerManager/target/usr/bin/docker-compose.v2.9.0-6413-g38f6acd >>
  new docker-compose created
New version of docker-compose returns:  v2.18.1

  to revert / replace with previous version, use the following command:
  sudo mv /var/packages/ContainerManager/target/usr/bin/docker-compose.v2.9.0-6413-g38f6acd /var/packages/ContainerManager/target/usr/bin/docker-compose

```

**Forcing update:**
To force-update docker-compose to the latest available version, run using the `--force` argument:

`sudo ./update_docker_compose.sh --force`

```
Current version of docker-compose: v2.18.1
Latest version of docker-compose: v2.18.1

Latest version of docker-compose already installed!
 - forcing update

Installing latest version of docker-compose...
Backing up current version of docker-compose...
  creating backup << /var/packages/ContainerManager/target/usr/bin/docker-compose.v2.18.1 >>
  new docker-compose created
New version of docker-compose returns:  v2.18.1

  to revert / replace with previous version, use the following command:
  sudo mv /var/packages/ContainerManager/target/usr/bin/docker-compose.v2.18.1 /var/packages/ContainerManager/target/usr/bin/docker-compose
```
