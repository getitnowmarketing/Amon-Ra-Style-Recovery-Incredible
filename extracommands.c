/* Getitnowmarketing
This was taken and modified from Koush's extendedcommands.c 
http://github.com/koush/android_bootable_recovery
To handle formatting non yaffs2 partitions like the ext3 /data & /cache on Incredible
*/
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "amend/commands.h"
#include "commands.h"
#include "common.h"
#include "cutils/misc.h"
#include "cutils/properties.h"
#include "firmware.h"
#include "minzip/DirUtil.h"
#include "minzip/Zip.h"
#include "roots.h"

#include "extracommands.h"
#include <signal.h>

#include <ctype.h>

#include <getopt.h>

#include <linux/input.h>

#include <dirent.h>

#include <sys/reboot.h>

#include <time.h>

#include <termios.h> 

#include "bootloader.h"
#include "install.h"
#include "minui/minui.h"

#include <sys/limits.h>

#include "recovery_ui_keys.h"

//disable this, its optional
int signature_check_enabled = 0;

void toggle_signature_check()
{
    signature_check_enabled = !signature_check_enabled;
    ui_print("Signature Check: %s\n", signature_check_enabled ? "Enabled" : "Disabled");
    if (signature_check_enabled == 0)  ui_print("Flashing unsigned zips may corrupt your system!\n");
}

int full_ext_format_enabled = 0;

void toggle_full_ext_format()
{
    full_ext_format_enabled = !full_ext_format_enabled;
    ui_print("Full Format Ext3/4: %s\n", full_ext_format_enabled ? "Enabled" : "Disabled");
    if (full_ext_format_enabled == 1)  ui_print("Full mke2fs format of ext3-ext4 enabled!\n");
}

void key_logger_test()
{
		//finish_recovery(NULL);
    		//ui_reset_progress();
		
		ui_print("Outputting key codes.\n");
                ui_print("Go back to end debugging.\n");
		
		for (;;) {
		int key = ui_wait_key();
                //int visible = ui_text_visible();

		if (key == GO_BACK) {
                   break;
               
		} else  {   
		   ui_print("Key: %d\n", key);
                }
           }               			
}

void run_script(char *str1,char *str2,char *str3,char *str4,char *str5,char *str6,char *str7)
{
	ui_print(str1);
        ui_clear_key_queue();
	ui_print("\nPress %s to confirm,", CONFIRM);
       	ui_print("\nany other key to abort.\n");
	int confirm = ui_wait_key();
		if (confirm == SELECT) {
                	ui_print(str2);
		        pid_t pid = fork();
                	if (pid == 0) {
                		char *args[] = { "/sbin/sh", "-c", str3, "1>&2", NULL };
                	        execv("/sbin/sh", args);
                	        fprintf(stderr, str4, strerror(errno));
                	        _exit(-1);
                	}
			int status;
			while (waitpid(pid, &status, WNOHANG) == 0) {
				ui_print(".");
               		        sleep(1);
			}
                	ui_print("\n");
			if (!WIFEXITED(status) || (WEXITSTATUS(status) != 0)) {
                		ui_print(str5);
                	} else {
                		ui_print(str6);
                	}
		} else {
	       		ui_print(str7);
       	        }
		if (!ui_text_visible()) return;
}


// This was pulled from bionic: The default system command always looks
// for shell in /system/bin/sh. This is bad.
#define _PATH_BSHELL "/sbin/sh"

extern char **environ;
int
__system(const char *command)
{
  pid_t pid;
    sig_t intsave, quitsave;
    sigset_t mask, omask;
    int pstat;
    char *argp[] = {"sh", "-c", NULL, NULL};

    if (!command)        /* just checking... */
        return(1);

    argp[2] = (char *)command;

    sigemptyset(&mask);
    sigaddset(&mask, SIGCHLD);
    sigprocmask(SIG_BLOCK, &mask, &omask);
    switch (pid = vfork()) {
    case -1:            /* error */
        sigprocmask(SIG_SETMASK, &omask, NULL);
        return(-1);
    case 0:                /* child */
        sigprocmask(SIG_SETMASK, &omask, NULL);
        execve(_PATH_BSHELL, argp, environ);
    _exit(127);
  }

    intsave = (sig_t)  bsd_signal(SIGINT, SIG_IGN);
    quitsave = (sig_t) bsd_signal(SIGQUIT, SIG_IGN);
    pid = waitpid(pid, (int *)&pstat, 0);
    sigprocmask(SIG_SETMASK, &omask, NULL);
    (void)bsd_signal(SIGINT, intsave);
    (void)bsd_signal(SIGQUIT, quitsave);
    return (pid == -1 ? -1 : pstat);
}

int format_non_mtd_device(const char* root)
{
    // if this is SDEXT:, don't worry about it.
    if (0 == strcmp(root, "SDEXT:"))
    {
        struct stat st;
        if (0 != stat("/dev/block/mmcblk1p2", &st))
        {
            ui_print("No app2sd partition found. Skipping format of /sd-ext.\n");
            return 0;
        }
    }

    char path[PATH_MAX];
    translate_root_path(root, path, PATH_MAX);
    if (0 != ensure_root_path_mounted(root))
    {
        ui_print("Error mounting %s!\n", path);
        ui_print("Skipping format...\n");
        return 0;
    }

    static char tmp[PATH_MAX];
    sprintf(tmp, "rm -rf %s/*", path);
    __system(tmp);
    sprintf(tmp, "rm -rf %s/.*", path);
    __system(tmp);
    
    ensure_root_path_unmounted(root);
    return 0;
}

void usb_toggle_sdcard()
{
	ui_print("\nEnabling USB-MS : ");
		        pid_t pid = fork();
                	if (pid == 0) {
                		char *args[] = { "/sbin/sh", "-c", "/sbin/ums_toggle on", "1>&2", NULL };
                	        execv("/sbin/sh", args);
                	        fprintf(stderr, "\nUnable to enable USB-MS!\n(%s)\n", strerror(errno));
                	        _exit(-1);
                	}
			int status;
			while (waitpid(pid, &status, WNOHANG) == 0) {
				ui_print(".");
               		        sleep(1);
			}
                	ui_print("\n");
			if (!WIFEXITED(status) || (WEXITSTATUS(status) != 0)) {
                		ui_print("\nError : Run 'ums_toggle' via adb!\n\n");
                	} else {
                                ui_clear_key_queue();
                		ui_print("\nUSB-MS enabled!");
				ui_print("\nPress %s to disable,", CONFIRM);
				ui_print("\nand return to menu\n");
		       		for (;;) {
        	                        	int key = ui_wait_key();
						if (key == SELECT) {
							ui_print("\nDisabling USB-MS : ");
						        pid_t pid = fork();
				                	if (pid == 0) {
				                		char *args[] = { "/sbin/sh", "-c", "/sbin/ums_toggle off", "1>&2", NULL };
                					        execv("/sbin/sh", args);
				                	        fprintf(stderr, "\nUnable to disable USB-MS!\n(%s)\n", strerror(errno));
				                	        _exit(-1);
				                	}
							int status;
							while (waitpid(pid, &status, WNOHANG) == 0) {
								ui_print(".");
				               		        sleep(1);
							}
				                	ui_print("\n");
							if (!WIFEXITED(status) || (WEXITSTATUS(status) != 0)) {
				                		ui_print("\nError : Run 'ums_toggle' via adb!\n\n");
				                	} else {
				                		ui_print("\nUSB-MS disabled!\n\n");
							}	
							break;
					        }
				} 
                	}
		}	
              
void usb_toggle_emmc()
{
		ui_print("\nEnabling USB-MS : ");
		        pid_t pid1 = fork();
                	if (pid1 == 0) {
                		char *args[] = { "/sbin/sh", "-c", "/sbin/ums_emmc_toggle on", "1>&2", NULL };
                	        execv("/sbin/sh", args);
                	        fprintf(stderr, "\nUnable to enable USB-MS!\n(%s)\n", strerror(errno));
                	        _exit(-1);
                	}
			int status1;
			while (waitpid(pid1, &status1, WNOHANG) == 0) {
				ui_print(".");
               		        sleep(1);
			}
                	ui_print("\n");
			if (!WIFEXITED(status1) || (WEXITSTATUS(status1) != 0)) {
                		ui_print("\nError : Run 'ums_emmc_toggle' via adb!\n\n");
                	} else {
                                ui_clear_key_queue();
                		ui_print("\nUSB-MS enabled!");
				ui_print("\nPress %s to disable,", CONFIRM);
				ui_print("\nand return to menu\n");
		       		for (;;) {
        	                        	int key = ui_wait_key();
						if (key == SELECT) {
							ui_print("\nDisabling USB-MS : ");
						        pid_t pid1 = fork();
				                	if (pid1 == 0) {
				                		char *args[] = { "/sbin/sh", "-c", "/sbin/ums_emmc_toggle off", "1>&2", NULL };
                					        execv("/sbin/sh", args);
				                	        fprintf(stderr, "\nUnable to disable USB-MS!\n(%s)\n", strerror(errno));
				                	        _exit(-1);
				                	}
							int status1;
							while (waitpid(pid1, &status1, WNOHANG) == 0) {
								ui_print(".");
				               		        sleep(1);
							}
				                	ui_print("\n");
							if (!WIFEXITED(status1) || (WEXITSTATUS(status1) != 0)) {
				                		ui_print("\nError : Run 'ums_emmc_toggle' via adb!\n\n");
				                	} else {
				                		ui_print("\nUSB-MS disabled!\n\n");
							}	
							break;
					        }
				} 
             }
   }	

void wipe_battery_stats()
{
    ensure_root_path_mounted("DATA:");
    remove("/data/system/batterystats.bin");
    ensure_root_path_unmounted("DATA:");
}

void wipe_rotate_settings()
{
    ensure_root_path_mounted("DATA:");
    __system("rm -r /data/misc/akmd*");
    __system("rm -r /data/misc/rild*");    
    ensure_root_path_unmounted("DATA:");
}     

void make_clockwork_path()
{
    ensure_root_path_mounted("SDCARD:");
    __system("mkdir -p /sdcard/clockworkmod/backup");
//    ensure_root_path_unmounted("SDCARD:");
} 

int format_ext3(const char* device, const char* mount_pt, const char* root)
{
ensure_root_path_unmounted(root);

if (0 != ensure_root_path_unmounted(root))
    {
	static char tmp_ext3[PATH_MAX];
	sprintf(tmp_ext3, "/sbin/umount %s", mount_pt);
	__system(tmp_ext3);
    }
if (0 != ensure_root_path_unmounted(root))
    {
        ui_print("Error unmounting %s!\n", mount_pt);
        ui_print("Skipping format...\n");
	return 0;
    }

static char fmt_ext3[PATH_MAX];
static char e2f_ext3[PATH_MAX];

sprintf(fmt_ext3, "/sbin/mke2fs -t ext3 %s", device);
__system(fmt_ext3);

sprintf(e2f_ext3, "/sbin/e2fsck -fp %s", device);
__system(e2f_ext3);

ui_print("Format of %s as ext3 complete\n\n", mount_pt);
return 0;
}

int format_ext4(const char* device, const char* mount_pt, const char* root)
{
ensure_root_path_unmounted(root);

if (0 != ensure_root_path_unmounted(root))
    {
	static char tmp_ext4[PATH_MAX];
	sprintf(tmp_ext4, "/sbin/umount %s", mount_pt);
	__system(tmp_ext4);
    }
if (0 != ensure_root_path_unmounted(root))
    {
        ui_print("Error unmounting %s!\n", mount_pt);
        ui_print("Skipping format...\n\n");
	return 0;
    }

static char fmt_ext4[PATH_MAX];
static char e2f_ext4[PATH_MAX];
static char upg_ext4[PATH_MAX];

sprintf(fmt_ext4, "/sbin/mke2fs -t ext3 %s", device);
__system(fmt_ext4);

sprintf(upg_ext4, "sbin/tune2fs -O extents,uninit_bg,dir_index %s", device);
__system(upg_ext4);

sprintf(e2f_ext4, "/sbin/e2fsck -fpDC0 %s", device);
__system(e2f_ext4);

ui_print("Format of %s as ext4 complete\n\n", mount_pt);
return 0;
}

int upgrade_ext3(const char* device, const char* mount_pt, const char* root)
{
LOGW("upgrade_ext3 %s %s %s\n", device, mount_pt, root);

ensure_root_path_unmounted(root);

if (0 != ensure_root_path_unmounted(root))
    {
	static char tmp_upg[PATH_MAX];
	sprintf(tmp_upg, "/sbin/umount %s", mount_pt);
	__system(tmp_upg);
    }
if (0 != ensure_root_path_unmounted(root))
    {
        ui_print("Error unmounting %s!\n", mount_pt);
        ui_print("Skipping format...\n\n");
	return 0;
    }

static char upg[PATH_MAX];
static char e2f_upg[PATH_MAX];

sprintf(upg, "sbin/tune2fs -O extents,uninit_bg,dir_index %s", device);
__system(upg);

sprintf(e2f_upg, "/sbin/e2fsck -fpDC0 %s", device);
__system(e2f_upg);

ui_print("Upgrade of %s to ext4 complete\n\n", mount_pt);
return 0;
}

void check_my_battery_level()
{
	
    char cap_s[3];
    
    FILE * cap = fopen("/sys/class/power_supply/battery/capacity","r");
    fgets(cap_s, 3, cap);
    fclose(cap);

    ui_print("\nBattery Level: %s%%\n\n", cap_s);
}

void check_fs() {
        
//	ensure_root_path_mounted("SYSTEM:");
	ensure_root_path_mounted("DATA:");
	ensure_root_path_mounted("CACHE:");

	static char discard[1024];
        char device[64], name[64], type[64];
        FILE *mounts = fopen("/proc/mounts", "r");
 	
        while (fscanf(mounts, "%64s %64s %64s %1024[^\n]", device, name, type, discard) != EOF) {
                /* Enjoy the whitespace! */
                if (
                        !strcmp(name, "/data") ||
            //            !strcmp(name, "/system") ||
                        !strcmp(name, "/cache") 
                 //       !strcmp(name, "/proc")
                )
                       
			 /* Only prints if filter matches */
                        ui_print("name: %s; type: %s\n", name, type);
  	}

	//ensure_root_path_unmounted("SYSTEM:");
	ensure_root_path_unmounted("DATA:");
	ensure_root_path_unmounted("CACHE:");
	fclose(mounts);
}

int check_fs_format(const char* root, const char* mnt_pt, int chk_for_upg_fs, int force_ext3) 
{

if (!strcmp(root, "SDEXT:")) {
	return 0;
	}

	if (!strcmp(root, "DATA:") || !strcmp(root, "CACHE:")) {

	ensure_root_path_mounted(root);

	if (0 != ensure_root_path_mounted(root)) {
        ui_print("Error mounting %s!\n", mnt_pt);
        return 0;
    	}

static char discard1[1024];
        char device1[64], name1[64], type1[64];
        FILE *mountsf = fopen("/proc/mounts", "r");
 	
        while (fscanf(mountsf, "%64s %64s %64s %1024[^\n]", device1, name1, type1, discard1) != EOF) {
                /* Enjoy the whitespace! */
                		
		if (
                        !strcmp(name1, mnt_pt)
		   )
		LOGW("name: %s; device: %s; type: %s\n", name1, device1, type1);		
	}
	fclose(mountsf);	
if (!strcmp(type1, "ext3") || !strcmp(type1, "ext4")) {
	return format_ext(device1, type1, mnt_pt, root, chk_for_upg_fs, force_ext3);
 } else {
	return 0;
	}
}	 			

return 0;	
}
int format_ext(const char *device, const char *type, const char *mount_pt, const char* root, int chk_for_upg_fs, int force_ext3)
{

ensure_root_path_unmounted(root);

if (0 != ensure_root_path_unmounted(root))
    {
	static char tmp1[PATH_MAX];
	sprintf(tmp1, "/sbin/umount %s", mount_pt);
	__system(tmp1);
    }
if (0 != ensure_root_path_unmounted(root))
    {
        ui_print("Error unmounting %s!\n", mount_pt);
        ui_print("Skipping format...\n\n");
	return 0;
    }

if (force_ext3) {
return format_ext3(device, mount_pt, root);
}

if (!strcmp(type, "ext3")) {

if (!chk_for_upg_fs) {

return format_ext3(device, mount_pt, root);

} else if (chk_for_upg_fs) {

return upgrade_ext3(device, mount_pt, root);
}

}
if (!strcmp(type, "ext4")) {

if (chk_for_upg_fs) {
ui_print("%s is already formatted as %s\n\n", mount_pt, type);
return 0;
}

return format_ext4(device, mount_pt, root);
}

return 0;
}

int get_boot_device(const char *root, const char* request)
{
char got_it[PATH_MAX];
get_root_device_info(root, request, got_it);
dump_device(got_it);
return 0;
}

int dump_device(const char *device)
{
static char dump[PATH_MAX];
sprintf(dump, "dump_image %s /tmp/mkboot/boot.img", device);
__system(dump);
LOGW("dump cmd is %s\n", dump);
return 0;
}

void unpack_boot()
{
__system("unpackbootimg /tmp/mkboot/boot.img /tmp/mkboot");
__system("mkbootimg.sh");
__system("flash_image boot /tmp/mkboot/newboot.img");
sync();
}

void setup_mkboot()
{
ensure_root_path_mounted("SDCARD:");
    __system("mkdir -p /sdcard/mkboot");
    __system("mkdir -p /sdcard/mkboot/zImage");
    __system("mkdir -p /sdcard/mkboot/modules");
    __system("rm /sdcard/mkboot/zImage/*");
    __system("rm /sdcard/mkboot/modules/*");
    __system("rm -rf /tmp/mkboot");
    __system("mkdir -p /tmp/mkboot");
    __system("chmod 0755 /tmp/mkboot/");
}

int check_file_exists(const char* file_path)
{
struct stat st;
if (0 != stat(file_path, &st)) {
	LOGW("Error %s doesn't exist\n", file_path);
	return -1;
} else {
	return 0;
}
}

int is_dir(const char* file_path)
/* dir ret 0, file ret 1, err ret -1 */
{
if (0 == (check_file_exists(file_path))) {
	struct stat s;
	stat(file_path, &s);
if (!(S_ISDIR(s.st_mode))) {
	return 0;
} else if (!(S_ISREG(s.st_mode))) {
	return 1;
} else {
	return -1;
}

}
return -1;
}


int copy_file(const char* source, const char* dest)
{
/* need to add a check to see if dest dir exists and volume is mounted */

if (0 == (is_dir(source))) {
	char copy[PATH_MAX];
	sprintf(copy, "cp -r %s %s", source, dest);
	__system(copy);
return 0;
}

if (1 == (is_dir(source))) {
	char copy[PATH_MAX];
	sprintf(copy, "cp %s %s", source, dest);
	__system(copy);
return 0;
}

return 1;
}

void do_module()
{
ensure_root_path_mounted("SYSTEM:");
ensure_root_path_mounted("SDCARD:");
__system("rm -rf /system/lib/modules");
__system("cp -r /sdcard/mkboot/modules /system/lib/modules");
__system("chmod 0755 /system/lib/modules");
__system("chmod 0644 /system/lib/modules/*");
ensure_root_path_unmounted("SYSTEM:");
ensure_root_path_unmounted("SDCARD:");
}

void do_make_new_boot()
{
setup_mkboot();
ui_print("\nConnect phone to pc");
ui_print("\nand copy new zImage and");
ui_print("\nmodules to /sdcard/mkboot");
ui_print("\nzImage & modules folder\n\n");
usb_toggle_sdcard();
ensure_root_path_mounted("SDCARD:");
dump_device("boot");
if (0 == (copy_file("/sdcard/mkboot/zImage/zImage", "/tmp/mkboot/zImage"))) {
	unpack_boot();
	do_module();
	ui_print("New boot created and flashed!!\n\n");
} else {
	ui_print("Error missing /sdcard/mkboot/zImage/zImage\n\n");
}
__system("rm -rf /tmp/mkboot");
}

void install_su(int eng_su)
{

ui_print("Working ......\n");
ensure_root_path_mounted("SYSTEM:");
ensure_root_path_mounted("DATA:");
ensure_root_path_mounted("CACHE:");

struct stat sd;
        if (0 == stat("/dev/block/mmcblk1p2", &sd)) {
ensure_root_path_mounted("SDEXT:");
__system("rm /sd-ext/dalvik-cache/*com.noshufou.android.su*classes.dex");
__system("rm -rf /sd-ext/data/com.noshufou.android.su");
__system("rm /sd-ext/app/com.noshufou.android.su*.apk");
__system("rm /sd-ext/dalvik-cache/*uperuser*classes.dex");
ensure_root_path_unmounted("SDEXT:");
}

__system("rm -rf /data/data/com.noshufou.android.su");
__system("rm /data/app/com.noshufou.android.su*.apk");
__system("rm /data/dalvik-cache/*com.noshufou.android.su*classes.dex");
__system("rm /data/dalvik-cache/*uperuser*classes.dex");

__system("rm /cache/dalvik-cache/*com.noshufou.android.su*classes.dex");
__system("rm /cache/dalvik-cache/*uperuser*classes.dex");

__system("rm /system/app/*uperuser.apk");

if ((0 == (check_file_exists("/system/bin/su"))) || (0 == (check_file_exists("/system/xbin/su"))) ){
	ui_print("Removing old su\n");
}
delete_file("/system/bin/su");
__system("rm /system/xbin/su");
if (!eng_su) {
	copy_file("/extra/su", "/system/bin/su");
	copy_file("/extra/Superuser.apk", "/system/app/Superuser.apk");
	__system("chmod 0644 /system/app/Superuser.apk");
} else {
	copy_file("/extra/suhack", "/system/bin/su");
}
__system("mkdir -p /system/xbin");
__system("chmod 06755 /system/bin/su");
__system("ln -s /system/bin/su /system/xbin/su");
ensure_root_path_unmounted("DATA:");
ensure_root_path_unmounted("SYSTEM:");
ensure_root_path_unmounted("CACHE:");
ui_print("su install complete\n\n");
}

int delete_file(const char* file)
{
/* need to add a check to see if volume is mounted */

if (0 == (is_dir(file))) {
	char del[PATH_MAX];
	sprintf(del, "rm -rf %s ", file);
	__system(del);
	return 0;
}

if (1 == (is_dir(file))) {
	char del[PATH_MAX];
	sprintf(del, "rm %s ", file);
	__system(del);
	return 0;
}

return 1;
}

void rb_bootloader()
{
sync();
ensure_root_path_unmounted("DATA:");
ensure_root_path_unmounted("EMMC:");
ensure_root_path_unmounted("SYSTEM:");
ensure_root_path_unmounted("CACHE:");
ensure_root_path_unmounted("SDCARD:");
ensure_root_path_unmounted("SDEXT:");
__system("/sbin/reboot bootloader");
}

void rb_recovery()
{
sync();
ensure_root_path_unmounted("DATA:");
ensure_root_path_unmounted("EMMC:");
ensure_root_path_unmounted("SYSTEM:");
ensure_root_path_unmounted("CACHE:");
ensure_root_path_unmounted("SDCARD:");
ensure_root_path_unmounted("SDEXT:");
__system("/sbin/reboot recovery");
}

