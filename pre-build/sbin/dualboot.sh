#!/sbin/sh

BB="/sbin/busybox"
DIMG="/sbin/dump_image"
DUALDIR=/sdcard/DualRom
CHECKMOUNTEDSD=`mount | grep /sdcard | awk '{print $2}'`
CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
DBDIR=/DualBoot
SETC=/system/etc
SYSBIN=/system/bin
FIMG="sbin/flash_image"
PHONEBOOT="/sdcard/DualRom/bootimages/Phoneboot.img"
INTERNALBOOT="/sdcard/DualRom/bootimages/internalboot.img"
SYSTYPE=`mount | grep /system | awk '{print $5}'`
DATATYPE=`mount | grep /data | awk '{print $5}'`
DATAMOUNT=`mount | grep /data | awk '{print $1}'`
CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
CHECKMOUNTEDCI=`mount | grep /cache-internal | awk '{print $2}'`
SYSBLOCK=`mount | grep /system | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
DATABLOCK=`mount | grep /data | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
CIBLOCK=`mount | grep /cache-internal | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
IMGSYSMOUNTED=0
IMGDATAMOUNTED=0
BACKUPPATH=/sdcard/DualRom/backups
TIMESTAMP="`date +%Y%m%d-%H%M`"
DESTDIR=foobar
RESTOREPATH=foobar
CACHEIMG=/emmc/cache.img
DATAIMG=/emmc/data.img
SYSTEMIMG=/emmc/system.img


case $1 in
	  setup-phone)

		if [ "$CHECKMOUNTEDSD" == "on" ]; then
			echo "/sdcard already mounted"
	 	else
			mount /sdcard 2>/dev/null
			sleep 2
	 	fi		

		if [ ! -d $DUALDIR/backups ]
		then
			"$BB" mkdir -p $DUALDIR/backups
		fi

		if [ ! -d $DUALDIR/bootimages ]
		then
			"$BB" mkdir -p $DUALDIR/bootimages
		fi

		if [ -e "$PHONEBOOT" ]
		then
			rm "$PHONEBOOT"
		fi

		if [ ! -e "$PHONEBOOT" ]
		then
			echo "Dumping Phone Rom's Boot.img"
			"$DIMG" boot "$PHONEBOOT"
		fi

	        if [ "$CHECKMOUNTEDSYS" == "on" ]; then
			echo "/system already mounted"
	 	
		SYSTYPE=`mount | grep /system | awk '{print $5}'`
		if [ "$SYSTYPE" == "yaffs2" ]; then
			echo "/nand system found"
		fi
		
		if [ "$SYSTYPE" == "ext3" ]; then
			echo "ext3 system found must unmount"
			umount /system 2>/dev/null
			
			mount /system 2>/dev/null
			sleep 2
		fi
		
		else
			mount /system 2>/dev/null
			sleep 2
	 	fi

		
		if [ ! -e $SETC/reboot ]; then
			"$BB" cp $DBDIR/reboot $SETC/reboot
			"$BB" chmod 0755 $SETC/reboot
		fi
		
		if [ ! -e $SYSBIN/flash_image ]; then
			"$BB" cp "$FIMG" $SYSBIN/flash_image
			"$BB" chmod 0755 $SYSBIN/flash_image
		fi


		if [ ! -e /system/app/DRSettingsv1.apk ]; then
			"$BB" cp $DBDIR/DRSettingsv1.apk /system/app/DRSettingsv1.apk
			"$BB" chmod 0644 /system/app/DRSettingsv1.apk
		fi

		sync

		CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
		if [ "$CHECKMOUNTEDSYS" == "on" ]; then
		
			umount /system 2>/dev/null
			sleep 2
	 	
		 fi
		
		;;

		phone-boot)
			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "/sdcard already mounted"
	 		else
				mount /sdcard 2>/dev/null
				sleep 2
	 		fi
			
			if [ -e "$PHONEBOOT" ]; then
				"$FIMG" boot "$PHONEBOOT"
				sync
				echo "PhoneBoot flashed"
		        else
				echo "error "$PHONEBOOT" not found"
				umount /sdcard 2>/dev/null
				exit 1
			fi
				
			CHECKMOUNTEDSD=`mount | grep /sdcard | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "unmounting /sdcard"
				umount /sdcard 2>/dev/null
				
			fi	

		;;

		internal-boot)
			
			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "/sdcard already mounted"
	 		else
				mount /sdcard 2>/dev/null
				sleep 2
	 		fi
			
			if [ -e "$INTERNALBOOT" ]; then
				"$FIMG" boot "$INTERNALBOOT"
				sync
				echo "InternalBoot flashed"
		        else
				echo "error "$INTERNALBOOT" not found"
				umount /sdcard 2>/dev/null
				exit 1
			fi
				
			CHECKMOUNTEDSD=`mount | grep /sdcard | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "unmounting /sdcard"
				umount /sdcard 2>/dev/null
			fi	

		;;

		wipe-systemext)
		
		CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
		if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
			echo "emmc mounted"
		else
			mount /emmc 2>/dev/null
			sleep 2
	 	fi

		CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
		if [ "$CHECKMOUNTEDSYS" == "on" ]; then
		
		SYSBLOCK=`mount | grep /system | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
		if [ "$SYSBLOCK" == "/dev/block/loop*" ]; then
			echo " system on ext3 found"
			IMGSYSMOUNTED=1
		else
			echo "yaffs2 /system is found"	
			echo "unmounting /system"
			umount /system 2>/dev/null
		fi
		
		fi

		if [ ! "$IMGSYSMOUNTED" == "1" ]; then
			if [ -e "$SYSTEMIMG" ]; then	
				"$BB" mount -o rw "$SYSTEMIMG" /system
				sleep 2
			else 
				echo "Critical: "$SYSTEMIMG" not found"
				exit 1
	 		fi
		fi

			cd /system
			echo "wiping system ext3"
			rm -rf ./*
			rm -rf .*
			echo "wipe done"
		;;

		wipe-dataext)
			
			# stock setup as mtdblock6 as /data/data & mmcblk0p1 as /data ensure we have the data.img

			CHECKMOUNTEDDATADATA=`mount | grep /dev/block/mtdblock6 | awk '{print $2}'`
		if [ "$CHECKMOUNTEDDATADATA" == "on" ];then
			umount /datadata 2>/dev/null
			
		fi			

			CHECKMOUNTED=`mount | grep /dev/block/mmcblk0p1 | awk '{print $2}'`
		if [ "$CHECKMOUNTED" == "on" ]; then
			
			CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
		 if [ "$CHECKMOUNTEDDATA" == "on" ];then	
			echo "wrong /data found"
			umount /data 2>/dev/null
	 	 fi			
		fi	
				
			CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
		if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
			echo "emmc mounted"
		else
			mount /emmc 2>/dev/null
			sleep 2
	 	fi
	
			CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
		if [ "$CHECKMOUNTEDDATA" == "on" ];then
			
			DATABLOCK=`mount | grep /data | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
		if [ "$DATABLOCK" == "/dev/block/loop*" ]; then
			echo " data.img is mounted on /data"
			IMGDATAMOUNTED=1
		else
			echo "wrong /data is found"	
			echo "unmounting /data"
			umount /data 2>/dev/null
		fi
		
		fi


		if [ ! "$IMGDATAMOUNTED" == "1" ]; then
			if [ -e "$DATAIMG" ]; then	
				"$BB" mount -o rw "$DATAIMG" /data
				sleep 2
		
		else 
				echo "Critical: "$DATAIMG" not found"
				exit 1
	 		fi	
		fi	
			cd /data
			echo "wiping data ext3.img"
			rm -rf ./*
			rm -rf .*
			echo "wipe done"
		;;
		
		wipe-cacheext)
		
			CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
			if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
				echo "emmc mounted"
			else
				mount /emmc 2>/dev/null
				sleep 2
	 		fi
	
			CHECKMOUNTEDCI=`mount | grep /cache-internal | awk '{print $2}'`
			if [ "$CHECKMOUNTEDCI" == "on" ]; then
				echo "cache-internal mounted"
			else
				if [ -e "$CACHEIMG" ]; then	
					"$BB" mount -o rw "$CACHEIMG" /cache-internal
					sleep 2
			
			else 
					echo "Critical: "$CACHEIMG" not found"
					exit 1
	 			fi
			fi
				cd /cache-internal
				echo "wiping cache-internal ext3.img"
				rm -rf ./*
				rm -rf .*
				echo "wipe done"
		;;
			
		cleanup)
			
			sync

			CHECKMOUNTEDCI=`mount | grep /cache-internal | awk '{print $2}'`
			if [ "$CHECKMOUNTEDCI" == "on" ]; then	
				
			CIBLOCK=`mount | grep /data | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [  "$CIBLOCK" == "/dev/block/loop*" ]; then	
				
				CILOOP=`mount | grep /cache-internal | awk '{print $1}'`
				echo "unmounting /cache.img on $CILOOP"
				umount /cache-internal 2>/dev/null
				
				"$BB" losetup -d "$CILOOP"
			else
				umount /cache-internal 2>/dev/null
				
			fi
			fi

			CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATA" == "on" ];then
			
			DATABLOCK=`mount | grep /data | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [  "$DATABLOCK" == "/dev/block/loop*" ]; then	
				
				DATALOOP=`mount | grep /data | awk '{print $1}'`
				echo "unmounting /data.img on $DATALOOP"
				umount /data 2>/dev/null
				
				"$BB" losetup -d "$DATALOOP"
			else
				umount /data 2>/dev/null
				
			fi
			fi

			CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSYS" == "on" ]; then
			
			SYSBLOCK=`mount | grep /system | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [  "$SYSBLOCK" == "/dev/block/loop*" ]; then	
				
				SYSLOOP=`mount | grep /system | awk '{print $1}'`
				echo "unmounting /system.img on $SYSLOOP"
				umount /system 2>/dev/null
				
				"$BB" losetup -d "$SYSLOOP"
			else
				umount /system 2>/dev/null
				
			fi
			fi

			CHECKMOUNTEDSD=`mount | grep /sdcard | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "unmounting /sdcard"
				umount /sdcard 2>/dev/null
					
			fi

			CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
			if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
				echo "unmounting /emmc"
				umount /emmc 2>/dev/null
					
			fi
		;;
		
		mount-img)
			
			CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
			if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
				echo "emmc mounted"
			else
				mount /emmc 2>/dev/null
				sleep 2
	 		fi

			CHECK=`mount | grep /emmc`
			if [ "$CHECK" == "" ]; then
          		echo "Critical: unable to mount emmc"
          			exit 1
			fi

			CHECKMOUNTEDDATADATA=`mount | grep /dev/block/mtdblock6 | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATADATA" == "on" ];then
				umount /datadata 2>/dev/null
				
			fi

			CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSYS" == "on" ]; then
				echo "unmounting /system"
				umount /system 2>/dev/null
							
			fi

			CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATA" == "on" ];then
				echo "unmounting /data"
				umount /data 2>/dev/null
			
			fi

			if [ -e "$SYSTEMIMG" ]; then	
				"$BB" mount -o rw "$SYSTEMIMG" /system
				sleep 2
			
			else 
				echo "Critical: "$SYSTEMIMG" not found"
				exit 1
	 		fi
			
			if [ -e "$DATAIMG" ]; then	
				"$BB" mount -o rw "$DATAIMG" /data
				sleep 2
			
			else 
				echo "Critical: "$DATAIMG" not found"
				exit 1
	 		fi	
		;;
				
		setup-internal)

		if [ "$CHECKMOUNTEDSD" == "on" ]; then
			echo "/sdcard already mounted"
	 	else
			mount /sdcard 2>/dev/null
			sleep 2
	 	fi
		
		CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
		if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
			echo "emmc mounted"
		else
			mount /emmc 2>/dev/null
			sleep 2
	 	fi
		
		if [ ! -d $DUALDIR/backups ]
		then
			"$BB" mkdir -p $DUALDIR/backups
		fi

		if [ ! -d $DUALDIR/bootimages ]
		then
			"$BB" mkdir -p $DUALDIR/bootimages
		fi

		if [ -e "$INTERNALBOOT" ]
		then
			rm "$INTERNALBOOT"
		fi

		if [ ! -e "$INTERNALBOOT" ]
		then
			echo "Dumping Internal Rom's Boot.img"
			"$DIMG" boot "$INTERNALBOOT"
		fi

	        if [ "$CHECKMOUNTEDSYS" == "on" ]; then
			echo "/system already mounted"
	 	
			SYSBLOCK=`mount | grep /system | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [ ! "$SYSBLOCK" == "/dev/block/loop*" ]; then
		 		echo "nand system found must unmount"
				umount /system 2>/dev/null
										
			if [ -e "$SYSTEMIMG" ]; then	
				"$BB" mount -o rw "$SYSTEMIMG" /system
				sleep 2
			
		else 
				echo "Critical: "$SYSTEMIMG" not found"
				exit 1
	 		fi

			fi
		
		fi
		
		if [ ! "$CHECKMOUNTEDSYS" == "on" ]; then		
			if [ -e "$SYSTEMIMG" ]; then	
				"$BB" mount -o rw "$SYSTEMIMG" /system
				sleep 2
		else 
				echo "Critical: "$SYSTEMIMG" not found"
				exit 1
			fi

	 	fi

		
		if [ ! -e $SETC/reboot ]; then
			"$BB" cp $DBDIR/reboot $SETC/reboot
			"$BB" chmod 0755 $SETC/reboot
		fi

		rm $SETC/vold.fstab
		"$BB" cp $DBDIR/vold.fstab $SETC/vold.fstab
		"$BB" chmod 0644 $SETC/vold.fstab

		if [ ! -e $SYSBIN/flash_image ]; then
			"$BB" cp "$FIMG" $SYSBIN/flash_image
			"$BB" chmod 0755 $SYSBIN/flash_image
		fi
		
		if [ ! -e /system/app/DRSettingsv1.apk ]; then
			"$BB" cp $DBDIR/DRSettingsv1.apk /system/app/DRSettingsv1.apk
			"$BB" chmod 0644 /system/app/DRSettingsv1.apk
		fi

			sync
		;;
		
		backup)
			
			CHECKMOUNTEDDATADATA=`mount | grep /dev/block/mtdblock6 | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATADATA" == "on" ];then
				umount /datadata 2>/dev/null
			fi	

			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "/sdcard already mounted"
	 		else
				mount /sdcard 2>/dev/null
				sleep 2
	 		fi
		
			CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
			if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
				echo "emmc mounted"
			else
				mount /emmc 2>/dev/null
				sleep 2
	 		fi

			CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSYS" == "on" ]; then
		
			SYSBLOCK=`mount | grep /system | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [ "$SYSBLOCK" == "/dev/block/loop*" ]; then
				echo " system on ext3 found"
				IMGSYSMOUNTED=1
			else
				echo "yaffs2 /system is found"	
				echo "unmounting /system"
				umount /system 2>/dev/null
			fi
		
			fi

			if [ ! "$IMGSYSMOUNTED" == "1" ]; then
			
				if [ -e "$SYSTEMIMG" ]; then	
					"$BB" mount -o rw "$SYSTEMIMG" /system
					sleep 2
				else 
					echo "Critical: "$SYSTEMIMG" not found"
					exit 1
	 			fi		
			fi

			CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATA" == "on" ];then
			
			DATABLOCK=`mount | grep /data | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [ "$DATABLOCK" == "/dev/block/loop*" ]; then
				echo " data.img is mounted on /data"
				IMGDATAMOUNTED=1
			else
				echo "wrong /data is found"	
				echo "unmounting /data"
				umount /data 2>/dev/null
			fi
		
			fi


			if [ ! "$IMGDATAMOUNTED" == "1" ]; then
				if [ -e "$DATAIMG" ]; then	
					"$BB" mount -o rw "$DATAIMG" /data
					sleep 2
			else 
					echo "Critical: "$DATAIMG" not found"
					exit 1
	 			fi	
			fi

			CHECKMOUNTEDCI=`mount | grep /cache-internal | awk '{print $2}'`
			if [ "$CHECKMOUNTEDCI" == "on" ]; then
				echo "cache-internal mounted"
			else
				if [ -e "$CACHEIMG" ]; then	
					"$BB" mount -o rw "$CACHEIMG" /cache-internal
					sleep 2
			else 
					echo "Critical: "$CACHEIMG" not found"
					exit 1
	 			fi
			fi

			if [ ! -d $BACKUPPATH ]; then
				"$BB" mkdir -p $BACKUPPATH
			fi
			
			DESTDIR="$BACKUPPATH/$TIMESTAMP"
			if [ ! -d $DESTDIR ]; then 
				mkdir -p $DESTDIR
			if [ ! -d $DESTDIR ]; then 
				echo "error: cannot create $DESTDIR"
				
				exit 1
			fi

			else
				touch $DESTDIR/.iswritable
			if [ ! -e $DESTDIR/.iswritable ]; then
				echo "error: cannot write to $DESTDIR"
		
				exit 1
			fi
				rm $DESTDIR/.iswritable
			fi

			echo "checking free space on sdcard"
			FREEBLOCKS="`df -k /sdcard| grep sdcard | awk '{ print $4 }'`"
			# we need about 500MB for the dump
			if [ $FREEBLOCKS -le 500000 ]; then
				echo "Error: not enough free space available on sdcard (need 500mb), aborting."
	
				exit 1
			fi
			
			CHECK=`mount | grep /cache-internal`
    			if [ "$CHECK" == "" ]; then
          		echo "Warning: unable to mount cache.img"
          			exit 1
    			else
			
			echo "Backing up cache.img"
				CWD=`pwd`
				cd /cache-internal
				tar -cvf $DESTDIR/cache.tar ./*
				cd $CWD
			fi

			CHECK=`mount | grep /system`
    			if [ "$CHECK" == "" ]; then
          		echo "Warning: unable to mount system.img"
          			exit 1
    			else
			
			echo "Backing up system.img"
				CWD=`pwd`
				cd /system
				tar -cvf $DESTDIR/system.tar ./*
				cd $CWD
			fi

			CHECK=`mount | grep /data`
    			if [ "$CHECK" == "" ]; then
          		echo "Warning: unable to mount data.img"
          			exit 1
    			else
			
			echo "Backing up data.img"
				CWD=`pwd`
				cd /data
				tar -cvf $DESTDIR/data.tar ./*
				cd $CWD
			fi

			echo "Backups Complete!"

			sync
		;;

		restore)	

			CHECKMOUNTEDDATADATA=`mount | grep /dev/block/mtdblock6 | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATADATA" == "on" ];then
				umount /datadata 2>/dev/null
			fi	

			if [ "$CHECKMOUNTEDSD" == "on" ]; then
				echo "/sdcard already mounted"
	 		else
				mount /sdcard 2>/dev/null
				sleep 2
	 		fi
		
			CHECKMOUNTEDEMMC=`mount | grep /emmc | awk '{print $2}'`
			if [ "$CHECKMOUNTEDEMMC" == "on" ]; then
				echo "emmc mounted"
			else
				mount /emmc 2>/dev/null
				sleep 2
	 		fi

			CHECKMOUNTEDSYS=`mount | grep /system | awk '{print $2}'`
			if [ "$CHECKMOUNTEDSYS" == "on" ]; then
		
			SYSBLOCK=`mount | grep /system | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [ "$SYSBLOCK" == "/dev/block/loop*" ]; then
				echo " system on ext3 found"
				IMGSYSMOUNTED=1
			else
				echo "yaffs2 /system is found"	
				echo "unmounting /system"
				umount /system 2>/dev/null
			fi
		
			fi

			if [ ! "$IMGSYSMOUNTED" == "1" ]; then
			
			if [ -e "$SYSTEMIMG" ]; then	
				"$BB" mount -o rw "$SYSTEMIMG" /system
				sleep 2
			else 
				echo "Critical: "$SYSTEMIMG" not found"
				exit 1
	 		fi		
			fi

			CHECKMOUNTEDDATA=`mount | grep /data | awk '{print $2}'`
			if [ "$CHECKMOUNTEDDATA" == "on" ];then
			
			DATABLOCK=`mount | grep /data | awk '{print $1}' |  sed 's/\(.*\)[0-9]/\1*/'`
			if [ "$DATABLOCK" == "/dev/block/loop*" ]; then
				echo " data.img is mounted on /data"
				IMGDATAMOUNTED=1
			else
				echo "wrong /data is found"	
				echo "unmounting /data"
				umount /data 2>/dev/null
			fi
		
			fi


			if [ ! "$IMGDATAMOUNTED" == "1" ]; then
				if [ -e "$DATAIMG" ]; then	
					"$BB" mount -o rw "$DATAIMG" /data
					sleep 2
			
			else 
					echo "Critical: "$DATAIMG" not found"
					exit 1
	 			fi	
			fi

			CHECKMOUNTEDCI=`mount | grep /cache-internal | awk '{print $2}'`
			if [ "$CHECKMOUNTEDCI" == "on" ]; then
				echo "cache-internal mounted"
			else
				if [ -e "$CACHEIMG" ]; then	
					"$BB" mount -o rw "$CACHEIMG" /cache-internal
					sleep 2
			
			else 
					echo "Critical: "$CACHEIMG" not found"
					exit 1
	 			fi
			fi

			# restore start
			if [ $2 = "" ]; then
				echo "No restore path parsed"
				exit 1
			else 
				echo "Restore Folder is $2"
			fi
			
			RESTOREPATH="$BACKUPPATH/$2"

			CHECK=`mount | grep /cache-internal`
    			if [ "$CHECK" == "" ]; then
          		echo "Warning: unable to mount cache.img"
          			exit 1
    			else
			
			echo "Restoring cache.img"
				CWD=`pwd`
				cd /cache-internal
				rm -rf ./* 2>/dev/null
				rm -rf .* 2>/dev/null
				tar -xvf $RESTOREPATH/cache.tar 
				cd $CWD
			fi
				
			CHECK=`mount | grep /system`
    			if [ "$CHECK" == "" ]; then
          		echo "Warning: unable to mount system.img"
          			exit 1
    			else
			
			echo "Restoring system.img"
				CWD=`pwd`
				cd /system
				rm -rf ./* 2>/dev/null
				rm -rf .* 2>/dev/null
				tar -xvf $RESTOREPATH/system.tar 
				cd $CWD
			fi

			CHECK=`mount | grep /data`
    			if [ "$CHECK" == "" ]; then
          		echo "Warning: unable to mount data.img"
          			exit 1
    			else
			
			echo "Restoring data.img"
				CWD=`pwd`
				cd /data
				rm -rf ./* 2>/dev/null
				rm -rf .* 2>/dev/null
				tar -xvf $RESTOREPATH/data.tar 
				cd $CWD
			fi
			echo "Restore Complete!"
			
			sync

		;;

		--)
		;;
esac

		
		exit 0
	
