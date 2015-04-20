# rdiff-save
rdiff-backup powered script using LVM snapshots when possible and checking repositories

Rename init.sh.sample to init.sh and set following variables:
	
	target		– backup storage absolute path;
	instance	– unique name of the backup in storage. Name of server may be;
	sources		– array of pathes that will be backed up;
	targets		– array of names of backup directories corresponding to pathes in $sources.
		If sources[x] path has no corresponding targets[x], backup dir name will be the same as last dir name of sources[x].
		Full path of backup directory will be $target/$instance/$targets[x].
		So, sample backup will be:
			/ → /mnt/backup/example.com/root
			/boot → /mnt/backup/example.com/boot
			/usr → /mnt/backup/example.com/usr
			/var → /mnt/backup/example.com/var
			/home → /mnt/backup/example.com/home
	excludes	– array of strings, that contain colon-separated absolute pathes. For every item of $sources may be one item in $excludes with same index.
		String '/path/one:/path/two' will be expanded to '--exclude /path/one --exclude /path/to'.
	vgs 			– virtual groups of LVM. Space-separated list of virtual groups configurations. Each configuration defined as <vg name>:<snapshot volume name>:<snapshot volume size>.
		Snapshot volume must not exist before backup script start. See lvcreate(8) for volume size format.
		Script automagicaly determines which virtual group device of backup source path belongs to or does not belong to any.
	snapshot	– mount point for snapshot volume.
	maxAge		– time of keeping backups. See rdiff-backup(1) for format of time period.
	remote		– URI of remote backup space. If specified, $target/$instance/ will be rsynced to.
	email			– mail address to send notifications to.
