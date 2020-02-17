# backupService

Reminder: I do not assume any liability for data losses. This was just a try out for myself. Usage of this tool is at your own risk!

This is a backup service with two choices:
 - create a new backup (simply copy given paths)
 - update the last backup, which was created (remove and copy files if there is a difference)

Both options can handle source path from different drives (C:, D: etc.).
The second option is done via hash comparison per directory. This means if you have multiple empty files at destination directory and source directory, it might be the case that files won't get removed or copied, due all of these files have the same hash value. Else I didn't experienced "unexpected" behaviour so far.

Created with PowerShell Version = 5.1.18362.145
