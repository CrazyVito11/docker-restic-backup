# Docker Restic Backup
Automatically makes periodic backups of a directory to a remote location via Restic running in Docker.

## Setup
### Container
1. GIT clone this repository using `git clone https://github.com/CrazyVito11/docker-restic-backup.git`
2. Copy `./config/.env.example` and call it `./config/.env`
3. Fill in `./config/.env`
4. Add your SSH key in `./config/ssh`
    - **Note:** We only need the private key, but it might be handy to also include your public key for quick access.
    - **Tip:** Don't have a key yet? You can generate one with `ssh-keygen -t rsa -N "" -f ./config/ssh/id_rsa`
5. Add the SSH fingerprint of your remote in `./config/ssh/known_hosts`
    - **Tip:** You can fetch it using `ssh-keyscan -H XXX.XXX.XXX.XXX >> ./config/ssh/known_hosts`, replacing the X with your remote server IP or hostname.
6. Start the Docker Compose project with `docker compose up -d --build`
7. Create the repository and backup with `docker compose exec docker-restic-backup bash /sync-now.sh --create-repository`

It should now automatically create the backup for you at the cron time you configured.

> [!WARNING]
> Make sure you store the configured password in a secure place like a password manager, as without those, your backups will be ***useless***!
>
> It's recommended you store your entire `./config/.env` and SSH keys there for a faster restore time if you ever need to fully restore from backups.

> [!TIP]
> If you make a configuration change, don't forget to rebuild container again.
> Just restarting the container won't work because the configuration files need to be regenerated.
>
> `docker compose down && docker compose up -d --build`


### Remote (backup server)
The configuration steps that are needed will depend on what kind of machine the remote server is, but it will need to fulfill these requirements:

1. Needs to run a SFTP server. _(Shell access is not required)_
2. A backup user has been made with username + SSH key authentication.
3. The backup directory has nothing else inside it.
4. The backup user has read and write access to the backup directory.
5. No other machine will save snapshots to the same Restic repository.
    - **Note:** You can still use the same remote for other machines, you just have to use a different directory to store the Restic repository in.

> [!TIP]
> If for some reason your server refuses the SSH key, double check the permissions of `.ssh` and `.ssh/authorized_keys` permissions are set properly.
>
> SSH servers will often refuse the configuration if it's not secure enough.


## Creating/restoring backups
### Create backup at remote
A cron job has already been configured to automatically run the backup, you can control the interval using the `BACKUP_CRON_INTERVAL` setting.

> [!TIP]
> You can use something like [cronjob.guru](https://crontab.guru/) if you aren't familiar with the cron time format.

In case you set the interval to make backups often and it starts to overlap, it will cancel new backup requests until the previous one is done.
This situation will also trigger the `Lock file exists` hook.


#### Make backup immediately
If you want to make the backup immediately, you can use the following command:

```bash
docker compose exec docker-restic-backup bash /sync-now.sh
```

> [!TIP]
> If you just want to validate what will happen when you run the sync, you can enable the `--dry-run` flag.
>
> This can be useful if you are setting up your own `excludes.txt` file.


### Restore from remote backup
> [!TIP]
> This container is mainly focused on making the backup itself, making sure it's done correctly and with easy monitoring capabilities.
>
> While it's also possible to restore files using this container, it isn't the most optimal experience due to limitations of running it containerized.
>
> It might be easier to just install Restic on the machine itself purely for restoring purposes.
> This will give you the ability to restore directly to the right directory or mount the repository.

#### Original server is still functional
If the server is still functional and you need to roll back or restore a deleted file for example, it's quite easy to do so.

First, it's recommended to activate the backup kill switch, this will prevent any backups from being made by accident during the restoration.
Set `BACKUP_KILL_SWITCH` to `true` in the `./config/.env` file and rebuild the container with `docker compose down && docker compose up -d --build`.

Then we can enter a shell with the required environment variables set to allow Restic to be run manually:

```bash
docker compose exec -e RESTIC_REPOSITORY_FILE=/config/restic-repository -e RESTIC_PASSWORD_FILE=/config/.restic-password docker-restic-backup bash
```

All restic commands in the sections below should be run inside this shell.

Then you can list the available snapshots to find the one you want to restore from:
```bash
restic snapshots
```

You can also browse the contents of a specific snapshot before restoring:
```bash
restic ls <snapshot-id>
```

> [!TIP]
> You can use `latest` as the snapshot ID to always target the most recent snapshot.


##### Understanding path mapping
The container mounts your `BACKUP_DIRECTORY` as `/data` _(read-only)_, and the backup is made from there.

This means snapshot paths are going to be relative to `BACKUP_DIRECTORY`.
To find the path to pass to `--include`, simply strip the `BACKUP_DIRECTORY` prefix from the host path:

| Host path                                        | Snapshot path _(use with `--include`)_ |
|--------------------------------------------------|----------------------------------------|
| `${BACKUP_DIRECTORY}/projects/myapp/config.json` | `/projects/myapp/config.json`          |
| `${BACKUP_DIRECTORY}/photos/2024`                | `/photos/2024`                         |

However, since `/data` is mounted read-only for safety reasons, we can't restore there directly.

As a workaround, we can restore files and snapshots to `/exports` instead _(mapped to `./exports` on the host)_, which is writable by the container.

After restoring, the files will be under `./exports` in the same sub-path structure they had originally.

##### Restoring commands
You can restore specific files and directories, or an entire snapshot if needed.
Both have their own use-cases and thus, both have been provided as an example.

After restoring, you can move the files from `./exports` back to their original location on the host.

> [!TIP]
> Once you've restored the files or snapshot, don't forget to disable the backup kill switch and rebuild the container. 😉

###### Restore specific files or directories
> [!WARNING]
> You should first read the [Understanding path mapping](#understanding-path-mapping) section to understand how to specify the `--include` parameter.

```bash
restic restore <snapshot-id> --target /exports --include "/path/to/file-or-directory/relative/from/BACKUP_DIRECTORY"
```

###### Restore an entire snapshot
```bash
restic restore <snapshot-id> --target /exports
```


#### Original server is no longer functional
If you need to restore from another machine or from a clean install, you will first have to execute a couple more steps before you can restore your data as usual.

First, make sure you have installed Docker again on the machine and have this repository cloned.

You will then need to restore the following files:
1. Your `./config/.env` file.
2. Your SSH keys.
3. Your SSH known hosts file.

You can now just follow the same instructions as if the server was still functional.


## Tips
### Exclude certain files/directories
There might be a chance you make a backup very globally, but might not want everything to be included.

For example application dependencies _(`vendor`, `node_modules`, etc...)_ might not be worth the extra space usage.

To fix this, you can create a `./config/excludes.txt` file with your exclude rules inside.
This file is then automatically passed to Restic if it exists.

`./config/excludes.txt.example` has also been provided that excludes some common directories that are _probably_ safe to ignore.
If you want to use this one, you can run this command to apply it `cp ./config/excludes.txt.example ./config/excludes.txt`.

For documentation about exclusion rules, see [the Restic documentation](https://restic.readthedocs.io/en/v0.18.1/040_backup.html#excluding-files).

> [!WARNING]
> Changing your excludes file still counts as a configuration change, and the container will have to be rebuild as usual.

> [!TIP]
> Since your backup directory is mounted as `/data` inside the container, use `/data/` as a prefix to exclude something specifically at the root of your backup directory.
>
> For example, if you are backing up your home directory _(example: `BACKUP_DIRECTORY="/home/your-username"`)_ and want to exclude `~/.cache`, add `/data/.cache` to your excludes file to specifically ignore that `.cache` directory.
>
> This is because Restic inside the container is running from `/data`, and the `excludes.txt` file expects a full path.
> Without this prefix, a pattern like `.cache` will match any directory with that name at _any_ depth in the backup.


### Run script during specific events
You have the ability to run your own Bash scripts at certain events, this can allow you to for example send notifications in case the sync completes or fails.

A couple of examples have been provided in the `hooks` directory.

| Event                | Script name               | Description                                                        |
|----------------------|---------------------------|--------------------------------------------------------------------|
| Backup success       | `backup-success.sh`       | Executed when the Restic command successfully finishes.            |
| Backup failure       | `backup-failure.sh`       | Executed when the Restic command ran against some kind of error.   |
| Lock file exists     | `lock-present.sh`         | Executed when the lock file exists, indicating it's still syncing. |
| Health check success | `health-check-success.sh` | Executed when the repository health check passes successfully.     |
| Health check failure | `health-check-failure.sh` | Executed when the repository health check fails.                   |
