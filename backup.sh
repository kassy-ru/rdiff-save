#!/bin/bash

{
	export PATH=/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	
	wd="$(realpath "$(dirname "$0")")"
	init="$wd/init.sh"
	[ -r "$init" ] || {
		echo "Couldn't open init file" >&2
		exit 1
	}
	
	. "$init"
	
	[ -d "$snapshot" ] || mkdir -p "$snapshot"
	
	declare -A backedUp
	mail="$(tempfile)"
	
	for i in ${!sources[*]}; do
		src=${sources[$i]}
		tgt=${targets[$i]}
		[ -z "$tgt" ] && tgt=$(echo $src | sed 's#.*/##')
		[ -z "$tgt" ] && \
		{
			echo "Misconfigured source '$src'" >&2
			exit 2
		}
		echo " = Backing up $src"
		
		mountPoint=
		for mpi in ${!mountPoints[*]}; do
			mp=${mountPoints[$mpi]}
			[[ ${#mp} -gt ${#mountPoint} && "$mp" == "${src:0:${#mp}}" ]] && mountPoint=$mp
		done
		
		fullTarget=$target/$instance/$tgt
		
		exclude=${excludes[$i]//:/ --exclude }
		[ -n "$exclude" ] && exclude=" --exclude $exclude"
		
		device=$(egrep -o "^/[^ ]+ $mountPoint " /proc/mounts | sed 's/ .*//')
		cfg=($(lvdisplay -c $device 2>/dev/null | sed 's/:/ /; s/:.*//'))
		snapshotting=
		if [[ ${#cfg[*]} -eq 2 ]]; then # device is logical volume
			lvPath=${cfg[0]}
			vgName=${cfg[1]}
			cfg=($(echo $vgs | egrep -o "(^| )$vgName:[^: ]+:[^: ]+( |$)" | sed -r "s/^(|.* )($vgName):([^ :]+):([^ :]+)( .*|)$/\3 \4/"))
			
			if [[ ${#cfg[*]} -ge 1 ]]; then # volume group configured
				snName=${cfg[0]}
				snPath=/dev/$vgName/$snName
				snSize=${cfg[1]}
				
				if [ -z "$snSize" ]; then
					snSize=-l100%FREE
				else
					echo $snSize | grep -qs '%' && snSize="-l$snSize" || snSize="-L$snSize"
				fi
				
				lvcreate $snSize -sn $snName $lvPath
				if [[ $? -eq 0 ]]; then
					mount $snPath $snapshot
					if [[ $? -eq 0 ]]; then
						snapshotting=yes
						sn="$snapshot"
						if [[ "$mountPoint" == '/' ]]; then
							src="$snapshot$src"
							sn="$sn/"
						else
							src="${src/$mountPoint/$snapshot}"
						fi
						exclude=${exclude// $mountPoint/ $sn}
					else
						echo "Warning: couldn't mount snapshot" >&2
						lvremove -f $snPath
					fi
				else
					echo "Warning: couldn't create snapshot" >&2
				fi
			fi
		fi
		
		rdiff-backup --exclude-other-filesystems$exclude $src $fullTarget
		if [[ $? -eq 0 ]]; then
			backedUp[$i]="$fullTarget"
		else
			echo "rdiff-backup --exclude-other-filesystems$exclude $src $fullTarget" >> "$mail"
		fi
		
		if [ -n "$snapshotting" ]; then
			umount $snPath
			lvremove -f $snPath
		fi
	done
	
	if [[ $(stat -c %s "$mail") -gt 0 ]]; then
		mail -s "[$instance] Backup errors" "$email" < "$mail"
	fi
	
	[ -n "$remote" ] && rsync -HAXax --delete $target/$instance/ $remote$instance
	
	> "$mail"
	error=
	for i in ${!backedUp[*]}; do
		path=${backedUp[$i]}
		
		rdiff-backup --force --remove-older-than $maxAge $path
		
		echo -e "\n\t=== $path\n" >> "$mail"
		rdiff-backup --verify $path 2>&1 >> "$mail" || error=yes
	done
	[ -n "$error" ] && mail -s "[$instance] Backup repo verification error" "$email" < "$mail"
	
	rm -f "$mail"

} 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' >> /var/log/backup
