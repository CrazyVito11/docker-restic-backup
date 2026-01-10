# Docker Restic Backup
Automatically makes periodic backups of a directory to a remote location via Restic running in Docker.

## Setup
### Container
1. Copy `./config/.env.example` and call it `./config/.env`
2. Fill in `./config/.env`
3. Add your SSH key in `./config/ssh`
    - **Note:** We only need the private key, but it might be handy to also include your public key for quick access.
    - **Tip:** Don't have a key yet? You can generate one with `ssh-keygen -t rsa -N "" -f ./config/ssh/id_rsa`
4. Add the SSH fingerprint of your remote in `./config/ssh/known_hosts`
    - **Tip:** You can fetch it using `ssh-keyscan -H XXX.XXX.XXX.XXX >> ./config/ssh/known_hosts`, replacing the X with your remote server IP or hostname.
5. Start the Docker Compose project with `docker compose up -d --build`
6. Create the repository and backup with `docker compose exec docker-restic-backup bash /sync-now.sh --create-repository`

It should now automatically create the backup for you at the cron time you configured.

> [!WARNING]
> Make sure you store the configured password in a secure place like a password manager, as without those, your backups will be ***useless***!
>
> It's recommended you also store your SSH key there for a faster restore time if you ever need to fully restore from backups.

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
***TODO:** Document this*


## Tips
### Exclude certain files/directories
There might be a chance you make a backup very globally, but might not want everything to be included.

For example application dependencies _(`vendor`, `node_modules`, etc...)_ might not be worth the extra space usage.

To fix this, you can create a `./config/excludes.txt` file with your exclude rules inside.
This file is then automatically passed to Restic if it exists.

`./config/excludes.txt.example` has also been provided that excludes some common directories that are _probably_ safe to ignore.
If you want to use this one, you can run this command to apply it `cp ./config/excludes.txt.example ./config/excludes.txt`.

For documentation about exclusion rules, see [the Restic documentation](https://restic.readthedocs.io/en/v0.18.1/040_backup.html#excluding-files).


### Run script during specific events
You have the ability to run your own Bash scripts at certain events, this can allow you to for example send notifications in case the sync completes or fails.

A couple of examples have been provided in the `hooks` directory.

| Event            | Script name         | Description                                                        |
|------------------|---------------------|--------------------------------------------------------------------|
| Backup success   | `backup-success.sh` | Executed when the Restic command successfully finishes.            |
| Backup failure   | `backup-failure.sh` | Executed when the Restic command ran against some kind of error.   |
| Lock file exists | `lock-present.sh`   | Executed when the lock file exists, indicating it's still syncing. |
