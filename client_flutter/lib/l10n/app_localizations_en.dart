// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get created => 'Created';

  @override
  String get modified => 'Modified';

  @override
  String get deleted => 'Deleted';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get noData => 'No data';

  @override
  String get settings => 'Settings';

  @override
  String get apiCallStats => 'API Call Statistics';

  @override
  String get callCount => 'Call count';

  @override
  String get syncServer => 'Sync Server';

  @override
  String get syncAccount => 'Sync Account';

  @override
  String get dataDirectory => 'Data Directory';

  @override
  String get theme => 'Theme';

  @override
  String get version => 'Version';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get loginExpired => 'Login expired, please login again';

  @override
  String get confirmLogout => 'Are you sure you want to logout?';

  @override
  String get logout => 'Logout';

  @override
  String get loggedIn => 'Logged in';

  @override
  String get autoLoginAvailable => 'Auto login available';

  @override
  String get needPassword => 'Password required';

  @override
  String get needServer => 'Server URL required';

  @override
  String get debugAndStats => 'Debug & Stats';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get dataDirCopied => 'Data directory copied to clipboard';

  @override
  String get sync => 'Sync';

  @override
  String get syncSuccess => 'Sync success';

  @override
  String get syncing => 'Syncing...';

  @override
  String get syncErrUnknown => 'Sync failed: Unknown error';

  @override
  String get syncErrNetwork =>
      'Sync failed: Network error, check your connection';

  @override
  String get syncErrTimeout => 'Sync failed: Request timeout, please retry';

  @override
  String get syncErrAuthInvalid => 'Login expired, please login again';

  @override
  String get syncErrConflict => 'Conflict detected, please resolve';

  @override
  String get syncErrServerDb => 'Sync failed: Server database error';

  @override
  String get syncErrRecordNotFound => 'Sync failed: Note not found';

  @override
  String get syncErrParams => 'Sync failed: Invalid parameters';

  @override
  String get syncErrRecordSave => 'Sync failed: Failed to save note';

  @override
  String get errorDetails => 'Error Details';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading...';

  @override
  String get recordLocked => 'Note is locked';

  @override
  String get enterPasswordToUnlock => 'Please enter password to unlock note';

  @override
  String get enterPassword => 'Please enter password';

  @override
  String get unlock => 'Unlock';

  @override
  String get passwordIncorrect => 'Password incorrect, please re-enter';

  @override
  String get saveRecordFailed => 'Save note failed';

  @override
  String get newRecord => 'New Note';

  @override
  String get emptyRecordsHint => 'No notes yet — tap to create your first one';

  @override
  String get upperLevel => 'Upper level';

  @override
  String moveRecordTo(Object file) {
    return 'Move $file to';
  }

  @override
  String get outOfBounds => 'Out of bounds';

  @override
  String get moveRecord => 'Move Note';

  @override
  String get newFolder => 'New Folder';

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get moveFolder => 'Move Folder';

  @override
  String get unlockRecord => 'Unlock Note';

  @override
  String get lockRecord => 'Lock Note';

  @override
  String get deleteRecord => 'Delete Note';

  @override
  String get rename => 'Rename';

  @override
  String get enterLockPassword => 'Enter lock password';

  @override
  String get enterUnlockPassword => 'Enter unlock password';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get markFinished => 'Mark as finished';

  @override
  String get markUnfinished => 'Mark as unfinished';

  @override
  String get lunar => 'Lunar';

  @override
  String movedToPath(Object fileName, Object path) {
    return 'Moved $fileName to $path';
  }

  @override
  String get multiSelect => 'Select';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String confirmDeleteSelectedRecords(Object count) {
    return 'Delete the selected $count notes?';
  }

  @override
  String deletedSelectedRecords(Object count) {
    return 'Deleted $count notes';
  }

  @override
  String movedSelectedRecords(Object count, Object path) {
    return 'Moved $count notes to $path';
  }

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeAmoled => 'AMOLED';

  @override
  String get themeLavender => 'Lavender';

  @override
  String get themeClassic => 'Classic';

  @override
  String get themeSolarized => 'Solarized';

  @override
  String get themeSky => 'Sky';

  @override
  String get themeSakura => 'Sakura';

  @override
  String get themeRoseGold => 'Rose Gold';

  @override
  String get lock => 'Lock';

  @override
  String lockUnlockFailedCheckPassword(Object operation) {
    return '$operation failed, please check password';
  }

  @override
  String get cannotReadRecordContent => 'Cannot read note content';

  @override
  String get login => 'Login';

  @override
  String get loginInvalidCredentials => 'Invalid username or password';

  @override
  String get changePassword => 'Change Password';

  @override
  String get oldPassword => 'Old Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmPassword => 'Confirm New Password';

  @override
  String get passwordMismatch => 'The two new passwords do not match';

  @override
  String get passwordChanged => 'Password changed, please login again';

  @override
  String get changePasswordFailed => 'Failed to change password';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get confirmDelete => 'Confirm Delete?';

  @override
  String get confirmDeleteThisRecord =>
      'Are you sure you want to delete this note?';

  @override
  String get confirmDeleteThisFolderAndAllRecords =>
      'Are you sure you want to delete this folder and all its notes?';

  @override
  String folderDeleted(Object folderPath) {
    return 'Deleted folder $folderPath';
  }

  @override
  String recordLockUnlockCompleted(Object operation) {
    return 'Note $operation completed';
  }

  @override
  String saveLockUnlockContentFailed(Object operation) {
    return 'Failed to save $operation content';
  }

  @override
  String recordDeleted(Object fileName) {
    return 'Deleted note $fileName';
  }

  @override
  String get isDeleted => 'Deleted';

  @override
  String get notExists => 'Not exists';

  @override
  String get noOpenRecords => 'No open notes';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get showAllTabs => 'Show all tabs';

  @override
  String get database => 'Database';

  @override
  String get operates => 'Logs';

  @override
  String get tombstoneManager => 'Server tombstone data cleanup';

  @override
  String get tombstoneManagerDesc =>
      'Purge soft-deleted records and orphaned assets';

  @override
  String get tombstoneTitle => 'Recycle Bin Statistics';

  @override
  String get tombstoneTotalRecords => 'Active records';

  @override
  String get tombstoneDeletedRecords => 'Soft-deleted records';

  @override
  String get tombstoneDeletedAssets => 'Orphaned assets';

  @override
  String get tombstoneMaxVersion => 'Max tombstone version';

  @override
  String get tombstonePurgedVersion => 'Purged version';

  @override
  String get tombstonePurge => 'Purge Now';

  @override
  String tombstonePurgeConfirm(Object count) {
    return 'Permanently delete $count soft-deleted records and all orphaned assets? This action cannot be undone.';
  }

  @override
  String tombstonePurgeDone(Object assets, Object count) {
    return 'Purged $count records and $assets orphaned assets';
  }

  @override
  String emptyInputCheck(Object input) {
    return 'Please input $input';
  }

  @override
  String get importDocument => 'Import Doc';

  @override
  String get importSuccess => 'Import record success';

  @override
  String get importFailed => 'Import record failed';

  @override
  String get importFolder => 'Import Folder';

  @override
  String get importNoFiles => 'No .md or .txt files found';

  @override
  String importCompleted(Object imported, Object skipped) {
    return 'Import done: $imported imported, $skipped skipped';
  }

  @override
  String get importDiscovering => 'Discovering linked documents...';

  @override
  String importingProgress(int done, int total) {
    return 'Importing ($done/$total)';
  }

  @override
  String get cancelled => 'Cancelled';

  @override
  String get collapseAll => 'Collapse All Folders';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get records => 'Notes';

  @override
  String get lastModify => 'Last Modified';

  @override
  String get closeOtherTabs => 'Close Other Tabs';

  @override
  String get closeAllTabs => 'Close All Tabs';

  @override
  String get closeTabsToRight => 'Close Tabs to the Right';

  @override
  String get closeTabsToLeft => 'Close Tabs to the Left';

  @override
  String get record => 'Note';

  @override
  String get sortType => 'Sort & View';

  @override
  String get sortTypeTreeFolder => 'Tree Folder';

  @override
  String get sortTypeFlatFolder => 'Flat Folder';

  @override
  String get sortTypeName => 'Sort by Name';

  @override
  String get sortTypeTime => 'Sort by Modified';

  @override
  String get allRecords => 'Notes';

  @override
  String get tags => 'Tags';

  @override
  String get tagTree => 'Tree Tags';

  @override
  String get tagFlat => 'Flat Tags';

  @override
  String get editTags => 'Edit Tags';

  @override
  String get addTag => 'Add Tag';

  @override
  String get tagName => 'Tag Name';

  @override
  String get done => 'Done';

  @override
  String get layoutMode => 'Layout Mode';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String syncConflictTitle(Object count) {
    return 'Sync Conflicts ($count)';
  }

  @override
  String get noConflicts => 'No conflicts';

  @override
  String get hasConflict => 'Conflict';

  @override
  String get recordConflict => 'Note Conflict';

  @override
  String get metaConflict => 'Meta Conflict';

  @override
  String get recordContentUnchangedMetaConflict =>
      'Note content unchanged, metadata conflict only. Please choose which side to keep.';

  @override
  String get conflictRemoteVersion => 'Remote Version';

  @override
  String get conflictLocalModified => 'Local Modifications';

  @override
  String get keepRemote => 'Keep Remote';

  @override
  String get keepLocal => 'Keep Local';

  @override
  String get orientationHorizontal => 'Horizontal Layout';

  @override
  String get orientationVertical => 'Vertical Layout';

  @override
  String get upgradeChecking => 'Checking...';

  @override
  String get upgradeCheckFailed => 'Check failed';

  @override
  String get upgradeUpToDate => 'Up to date ✓';

  @override
  String upgradeAvailable(Object version) {
    return 'New version $version available';
  }

  @override
  String upgradeCurrentVersion(Object current, Object latest) {
    return 'Current: v$current → Latest: $latest';
  }

  @override
  String get upgradeChangelog => 'Changelog';

  @override
  String get upgradeNoChangelog => '(none)';

  @override
  String get upgradeCopyDownloadUrl => 'Copy download URL';

  @override
  String upgradeDownloadCopied(Object url) {
    return 'Download URL copied: $url';
  }

  @override
  String get upgradeIOS => 'iOS: update via App Store';

  @override
  String upgradeServerUrl(Object url) {
    return 'via $url';
  }

  @override
  String get upgradeDownloadAndInstall => 'Download & Install';

  @override
  String get upgradeReinstall => 'Reinstall current version';

  @override
  String get upgradeDownloading => 'Downloading...';

  @override
  String get upgradeDownloadSuccess => 'Download complete';

  @override
  String get upgradeDownloadFailed => 'Download failed';

  @override
  String get switchToPad => 'Switch to tablet mode';

  @override
  String get switchToPhone => 'Switch to phone mode';

  @override
  String get switchToDesktop => 'Switch to desktop mode';

  @override
  String get modeDesktop => 'Desktop mode';

  @override
  String get modePad => 'Tablet mode';

  @override
  String get modePhone => 'Phone mode';

  @override
  String get rememberOpenTabs => 'Remember open records';

  @override
  String get rememberOpenTabsDesc => 'Restore tabs and selection on startup';

  @override
  String get reminderTasks => 'Reminders';

  @override
  String get noReminderTasks => 'No reminders';

  @override
  String get unnamedTask => 'Untitled';

  @override
  String get notSet => 'Not set';

  @override
  String get repeatOnce => 'Once';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get taskName => 'Task name';

  @override
  String get repeat => 'Repeat';

  @override
  String get save => 'Save';

  @override
  String get addReminder => 'Add reminder';

  @override
  String get weekdays => 'Mon|Tue|Wed|Thu|Fri|Sat|Sun';

  @override
  String get calendar => 'Calendar';

  @override
  String get noRemindersToday => 'No reminders today';

  @override
  String get reminder => 'Reminder';

  @override
  String get today => 'Today';

  @override
  String repeatMonthlyTime(int day, String time) {
    return 'Every month day $day $time';
  }

  @override
  String repeatYearlyTime(int month, int day, String time) {
    return 'Every year $month/$day $time';
  }

  @override
  String get reminderChannel => 'Reminder';

  @override
  String get reminderChannelDesc => 'Note task reminders';

  @override
  String get reminderDueBody => 'This reminder is due';

  @override
  String get searchRecords => 'Search notes';

  @override
  String get searchHistory => 'Search history';

  @override
  String get clearSearchHistory => 'Clear';

  @override
  String get searchNoResults => 'No matches';

  @override
  String get unitYear => 'y';

  @override
  String get unitMonth => 'm';

  @override
  String get unitDay => 'd';

  @override
  String get unitHour => 'h';

  @override
  String get unitMinute => 'min';

  @override
  String get atLeastOneWeekday => 'Please select at least one weekday';

  @override
  String get recycler => 'Recycle bin';

  @override
  String get purgeRecyclerItem => 'Delete permanently';

  @override
  String get clearRecycler => 'Empty recycle bin';

  @override
  String get confirmClearRecycler =>
      'Permanently delete all items in the recycle bin?';

  @override
  String get confirmPurgeRecycler =>
      'Delete permanently? This cannot be undone.';

  @override
  String recyclerAutoClearHint(int days) {
    return 'Recycler entries are auto-cleared after $days days';
  }

  @override
  String recyclerRestored(String name) {
    return 'Restored $name';
  }

  @override
  String get recyclerRestoreFailed => 'Restore failed';

  @override
  String get recyclerPurged => 'Deleted permanently';

  @override
  String get recyclerCleared => 'Recycle bin emptied';

  @override
  String get importExport => 'Import / Export';

  @override
  String get exportMd => 'Export MD';

  @override
  String get exportSelectFolder => 'Select destination folder';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get exportNoRecords => 'No notes in this folder';

  @override
  String exportingProgress(int done, int total) {
    return 'Exporting $done/$total';
  }

  @override
  String get exportEncryptedTitle =>
      'Encrypted document, please enter password';

  @override
  String get exportSkip => 'Skip';

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String get share => 'Share';

  @override
  String get shareDays => 'days';

  @override
  String get shareHours => 'hours';

  @override
  String get shareExpireHint => 'Link expires in';

  @override
  String get shareCreating => 'Creating share link…';

  @override
  String get shareFailed => 'Share failed';

  @override
  String get shareInvalidExpire => 'Duration must be > 0 and ≤ 30 days';

  @override
  String get shareLinkCopied => 'Link copied to clipboard';

  @override
  String exportCompleted(int success, int skipped) {
    return 'Export completed: $success exported, $skipped skipped';
  }

  @override
  String get exportOpenFolder => 'Open folder';

  @override
  String get outline => 'Outline';

  @override
  String get noHeadings => 'No headings';

  @override
  String get wordCount => 'Word count';

  @override
  String get todoList => 'Todo';

  @override
  String get table => 'Table';

  @override
  String get insertTime => 'Insert time';

  @override
  String get recordInfo => 'Note info';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get confirmClearLogs =>
      'Are you sure you want to clear all logs? This cannot be undone.';

  @override
  String get logsCleared => 'Logs cleared';

  @override
  String get clearFailed => 'Clear failed';

  @override
  String get filterAll => 'All';

  @override
  String get filterLevel => 'Filter level';

  @override
  String get account => 'Account';

  @override
  String get addAccount => 'Add account';

  @override
  String get switchAccountFailed => 'Failed to switch account';

  @override
  String get loadingUserData => 'Loading user data...';

  @override
  String get image => 'Image';

  @override
  String get codeBlock => 'Code Block';

  @override
  String get textFormat => 'Text Format';

  @override
  String get heading => 'Heading';
}
