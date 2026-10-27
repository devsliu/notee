import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @created.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get created;

  /// No description provided for @modified.
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get modified;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleted;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @apiCallStats.
  ///
  /// In zh, this message translates to:
  /// **'API调用统计'**
  String get apiCallStats;

  /// No description provided for @callCount.
  ///
  /// In zh, this message translates to:
  /// **'调用次数'**
  String get callCount;

  /// No description provided for @syncServer.
  ///
  /// In zh, this message translates to:
  /// **'同步服务器'**
  String get syncServer;

  /// No description provided for @syncAccount.
  ///
  /// In zh, this message translates to:
  /// **'同步账号'**
  String get syncAccount;

  /// No description provided for @dataDirectory.
  ///
  /// In zh, this message translates to:
  /// **'数据目录'**
  String get dataDirectory;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @notLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notLoggedIn;

  /// No description provided for @loginExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录失效,请重新登陆'**
  String get loginExpired;

  /// No description provided for @confirmLogout.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get confirmLogout;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @loggedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get loggedIn;

  /// No description provided for @autoLoginAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可一键登录'**
  String get autoLoginAvailable;

  /// No description provided for @needPassword.
  ///
  /// In zh, this message translates to:
  /// **'需要密码'**
  String get needPassword;

  /// No description provided for @needServer.
  ///
  /// In zh, this message translates to:
  /// **'需要服务器地址'**
  String get needServer;

  /// No description provided for @debugAndStats.
  ///
  /// In zh, this message translates to:
  /// **'调试与统计'**
  String get debugAndStats;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @selectTheme.
  ///
  /// In zh, this message translates to:
  /// **'选择主题'**
  String get selectTheme;

  /// No description provided for @dataDirCopied.
  ///
  /// In zh, this message translates to:
  /// **'数据目录已复制到剪贴板'**
  String get dataDirCopied;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @syncSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncSuccess;

  /// No description provided for @syncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步...'**
  String get syncing;

  /// No description provided for @syncErrUnknown.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 未知错误'**
  String get syncErrUnknown;

  /// No description provided for @syncErrNetwork.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 网络连接异常, 请检查网络'**
  String get syncErrNetwork;

  /// No description provided for @syncErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 请求超时, 请稍后重试'**
  String get syncErrTimeout;

  /// No description provided for @syncErrAuthInvalid.
  ///
  /// In zh, this message translates to:
  /// **'登录状态已失效, 请重新登录'**
  String get syncErrAuthInvalid;

  /// No description provided for @syncErrConflict.
  ///
  /// In zh, this message translates to:
  /// **'有冲突笔记, 请点击解决'**
  String get syncErrConflict;

  /// No description provided for @syncErrServerDb.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 服务端数据库错误'**
  String get syncErrServerDb;

  /// No description provided for @syncErrRecordNotFound.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 笔记不存在'**
  String get syncErrRecordNotFound;

  /// No description provided for @syncErrParams.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 参数错误'**
  String get syncErrParams;

  /// No description provided for @syncErrRecordSave.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: 笔记保存失败'**
  String get syncErrRecordSave;

  /// No description provided for @errorDetails.
  ///
  /// In zh, this message translates to:
  /// **'错误详情'**
  String get errorDetails;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @recordLocked.
  ///
  /// In zh, this message translates to:
  /// **'笔记已锁定'**
  String get recordLocked;

  /// No description provided for @enterPasswordToUnlock.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码解锁笔记'**
  String get enterPasswordToUnlock;

  /// No description provided for @enterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get enterPassword;

  /// No description provided for @unlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// No description provided for @passwordIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'密码错误，请重新输入'**
  String get passwordIncorrect;

  /// No description provided for @saveRecordFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存笔记失败'**
  String get saveRecordFailed;

  /// No description provided for @newRecord.
  ///
  /// In zh, this message translates to:
  /// **'新建笔记'**
  String get newRecord;

  /// No description provided for @emptyRecordsHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有笔记，点击创建第一条'**
  String get emptyRecordsHint;

  /// No description provided for @upperLevel.
  ///
  /// In zh, this message translates to:
  /// **'上一级'**
  String get upperLevel;

  /// No description provided for @moveRecordTo.
  ///
  /// In zh, this message translates to:
  /// **'移动笔记 {file} 到'**
  String moveRecordTo(Object file);

  /// No description provided for @outOfBounds.
  ///
  /// In zh, this message translates to:
  /// **'超出范围'**
  String get outOfBounds;

  /// No description provided for @moveRecord.
  ///
  /// In zh, this message translates to:
  /// **'移动笔记'**
  String get moveRecord;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @deleteFolder.
  ///
  /// In zh, this message translates to:
  /// **'删除文件夹'**
  String get deleteFolder;

  /// No description provided for @renameFolder.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件夹'**
  String get renameFolder;

  /// No description provided for @moveFolder.
  ///
  /// In zh, this message translates to:
  /// **'移动文件夹'**
  String get moveFolder;

  /// No description provided for @unlockRecord.
  ///
  /// In zh, this message translates to:
  /// **'解锁笔记'**
  String get unlockRecord;

  /// No description provided for @lockRecord.
  ///
  /// In zh, this message translates to:
  /// **'锁定笔记'**
  String get lockRecord;

  /// No description provided for @deleteRecord.
  ///
  /// In zh, this message translates to:
  /// **'删除笔记'**
  String get deleteRecord;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @enterLockPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入加锁密码'**
  String get enterLockPassword;

  /// No description provided for @enterUnlockPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入解锁密码'**
  String get enterUnlockPassword;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @markFinished.
  ///
  /// In zh, this message translates to:
  /// **'标记为完成'**
  String get markFinished;

  /// No description provided for @markUnfinished.
  ///
  /// In zh, this message translates to:
  /// **'标记为未完成'**
  String get markUnfinished;

  /// No description provided for @lunar.
  ///
  /// In zh, this message translates to:
  /// **'农历'**
  String get lunar;

  /// No description provided for @movedToPath.
  ///
  /// In zh, this message translates to:
  /// **'已将 {fileName} 移动到 {path}'**
  String movedToPath(Object fileName, Object path);

  /// No description provided for @multiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get multiSelect;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 项'**
  String selectedCount(Object count);

  /// No description provided for @confirmDeleteSelectedRecords.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个笔记吗？'**
  String confirmDeleteSelectedRecords(Object count);

  /// No description provided for @deletedSelectedRecords.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个笔记'**
  String deletedSelectedRecords(Object count);

  /// No description provided for @movedSelectedRecords.
  ///
  /// In zh, this message translates to:
  /// **'已将 {count} 个笔记移动到 {path}'**
  String movedSelectedRecords(Object count, Object path);

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeMidnight.
  ///
  /// In zh, this message translates to:
  /// **'午夜'**
  String get themeMidnight;

  /// No description provided for @themeAmoled.
  ///
  /// In zh, this message translates to:
  /// **'纯黑'**
  String get themeAmoled;

  /// No description provided for @themeLavender.
  ///
  /// In zh, this message translates to:
  /// **'薰衣草紫'**
  String get themeLavender;

  /// No description provided for @themeClassic.
  ///
  /// In zh, this message translates to:
  /// **'古典'**
  String get themeClassic;

  /// No description provided for @themeSolarized.
  ///
  /// In zh, this message translates to:
  /// **'日光'**
  String get themeSolarized;

  /// No description provided for @themeSky.
  ///
  /// In zh, this message translates to:
  /// **'天蓝'**
  String get themeSky;

  /// No description provided for @themeSakura.
  ///
  /// In zh, this message translates to:
  /// **'樱花'**
  String get themeSakura;

  /// No description provided for @themeRoseGold.
  ///
  /// In zh, this message translates to:
  /// **'玫瑰金'**
  String get themeRoseGold;

  /// No description provided for @pleaseSelectRecord.
  ///
  /// In zh, this message translates to:
  /// **'请选择笔记'**
  String get pleaseSelectRecord;

  /// No description provided for @lock.
  ///
  /// In zh, this message translates to:
  /// **'加锁'**
  String get lock;

  /// No description provided for @lockUnlockFailedCheckPassword.
  ///
  /// In zh, this message translates to:
  /// **'{operation}失败，请检查密码'**
  String lockUnlockFailedCheckPassword(Object operation);

  /// No description provided for @cannotReadRecordContent.
  ///
  /// In zh, this message translates to:
  /// **'无法读取笔记内容'**
  String get cannotReadRecordContent;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In zh, this message translates to:
  /// **'用户名或密码错误'**
  String get loginInvalidCredentials;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @oldPassword.
  ///
  /// In zh, this message translates to:
  /// **'旧密码'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get passwordMismatch;

  /// No description provided for @passwordChanged.
  ///
  /// In zh, this message translates to:
  /// **'密码修改成功, 请重新登录'**
  String get passwordChanged;

  /// No description provided for @changePasswordFailed.
  ///
  /// In zh, this message translates to:
  /// **'修改密码失败'**
  String get changePasswordFailed;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteThisRecord.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个笔记吗？'**
  String get confirmDeleteThisRecord;

  /// No description provided for @confirmDeleteThisFolderAndAllRecords.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个文件夹及其所有笔记吗？'**
  String get confirmDeleteThisFolderAndAllRecords;

  /// No description provided for @folderDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除文件夹 {folderPath}'**
  String folderDeleted(Object folderPath);

  /// No description provided for @recordLockUnlockCompleted.
  ///
  /// In zh, this message translates to:
  /// **'笔记{operation}完成'**
  String recordLockUnlockCompleted(Object operation);

  /// No description provided for @saveLockUnlockContentFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存{operation}内容失败'**
  String saveLockUnlockContentFailed(Object operation);

  /// No description provided for @recordDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除笔记 {fileName}'**
  String recordDeleted(Object fileName);

  /// No description provided for @isDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get isDeleted;

  /// No description provided for @notExists.
  ///
  /// In zh, this message translates to:
  /// **'不存在'**
  String get notExists;

  /// No description provided for @noOpenRecords.
  ///
  /// In zh, this message translates to:
  /// **'未打开笔记'**
  String get noOpenRecords;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @selectLanguage.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get selectLanguage;

  /// No description provided for @minimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In zh, this message translates to:
  /// **'最大化'**
  String get maximize;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'还原'**
  String get restore;

  /// No description provided for @windowClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get windowClose;

  /// No description provided for @showAllTabs.
  ///
  /// In zh, this message translates to:
  /// **'显示所有标签页'**
  String get showAllTabs;

  /// No description provided for @database.
  ///
  /// In zh, this message translates to:
  /// **'数据库'**
  String get database;

  /// No description provided for @operates.
  ///
  /// In zh, this message translates to:
  /// **'操作日志'**
  String get operates;

  /// No description provided for @tombstoneManager.
  ///
  /// In zh, this message translates to:
  /// **'服务单墓碑数据清理'**
  String get tombstoneManager;

  /// No description provided for @tombstoneManagerDesc.
  ///
  /// In zh, this message translates to:
  /// **'清理服务端软删除笔记和孤立附件'**
  String get tombstoneManagerDesc;

  /// No description provided for @tombstoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'回收站统计'**
  String get tombstoneTitle;

  /// No description provided for @tombstoneTotalRecords.
  ///
  /// In zh, this message translates to:
  /// **'活跃记录'**
  String get tombstoneTotalRecords;

  /// No description provided for @tombstoneDeletedRecords.
  ///
  /// In zh, this message translates to:
  /// **'软删除记录'**
  String get tombstoneDeletedRecords;

  /// No description provided for @tombstoneDeletedAssets.
  ///
  /// In zh, this message translates to:
  /// **'孤立附件'**
  String get tombstoneDeletedAssets;

  /// No description provided for @tombstoneMaxVersion.
  ///
  /// In zh, this message translates to:
  /// **'全表最大版本'**
  String get tombstoneMaxVersion;

  /// No description provided for @tombstonePurgedVersion.
  ///
  /// In zh, this message translates to:
  /// **'墓碑版本号'**
  String get tombstonePurgedVersion;

  /// No description provided for @tombstonePurge.
  ///
  /// In zh, this message translates to:
  /// **'立即清理'**
  String get tombstonePurge;

  /// No description provided for @tombstonePurgeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将永久删除 {count} 条软删除笔记和所有孤立附件，操作不可恢复。'**
  String tombstonePurgeConfirm(Object count);

  /// No description provided for @tombstonePurgeDone.
  ///
  /// In zh, this message translates to:
  /// **'已清理 {count} 条笔记和 {assets} 个孤立附件'**
  String tombstonePurgeDone(Object assets, Object count);

  /// No description provided for @emptyInputCheck.
  ///
  /// In zh, this message translates to:
  /// **'请输入{input}'**
  String emptyInputCheck(Object input);

  /// No description provided for @importDocument.
  ///
  /// In zh, this message translates to:
  /// **'导入文档'**
  String get importDocument;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'笔记导入成功'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'笔记导入失败'**
  String get importFailed;

  /// No description provided for @importFolder.
  ///
  /// In zh, this message translates to:
  /// **'导入文件夹'**
  String get importFolder;

  /// No description provided for @importNoFiles.
  ///
  /// In zh, this message translates to:
  /// **'未找到 .md 或 .txt 文件'**
  String get importNoFiles;

  /// No description provided for @importCompleted.
  ///
  /// In zh, this message translates to:
  /// **'导入完成：成功 {imported} 个，跳过 {skipped} 个'**
  String importCompleted(Object imported, Object skipped);

  /// No description provided for @importDiscovering.
  ///
  /// In zh, this message translates to:
  /// **'正在发现关联文档...'**
  String get importDiscovering;

  /// No description provided for @importingProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在导入 ({done}/{total})'**
  String importingProgress(int done, int total);

  /// No description provided for @cancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get cancelled;

  /// No description provided for @collapseAll.
  ///
  /// In zh, this message translates to:
  /// **'收起所有文件夹'**
  String get collapseAll;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get redo;

  /// No description provided for @records.
  ///
  /// In zh, this message translates to:
  /// **'篇笔记'**
  String get records;

  /// No description provided for @lastModify.
  ///
  /// In zh, this message translates to:
  /// **'上次修改'**
  String get lastModify;

  /// No description provided for @closeOtherTabs.
  ///
  /// In zh, this message translates to:
  /// **'关闭其他标签'**
  String get closeOtherTabs;

  /// No description provided for @closeAllTabs.
  ///
  /// In zh, this message translates to:
  /// **'关闭所有标签'**
  String get closeAllTabs;

  /// No description provided for @closeTabsToRight.
  ///
  /// In zh, this message translates to:
  /// **'关闭右侧标签'**
  String get closeTabsToRight;

  /// No description provided for @closeTabsToLeft.
  ///
  /// In zh, this message translates to:
  /// **'关闭左侧标签'**
  String get closeTabsToLeft;

  /// No description provided for @record.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get record;

  /// No description provided for @sortType.
  ///
  /// In zh, this message translates to:
  /// **'查看与排序'**
  String get sortType;

  /// No description provided for @sortTypeTreeFolder.
  ///
  /// In zh, this message translates to:
  /// **'树形文件夹'**
  String get sortTypeTreeFolder;

  /// No description provided for @sortTypeFlatFolder.
  ///
  /// In zh, this message translates to:
  /// **'平铺文件夹'**
  String get sortTypeFlatFolder;

  /// No description provided for @sortTypeName.
  ///
  /// In zh, this message translates to:
  /// **'按名字排序'**
  String get sortTypeName;

  /// No description provided for @sortTypeTime.
  ///
  /// In zh, this message translates to:
  /// **'按时间排序'**
  String get sortTypeTime;

  /// No description provided for @allRecords.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get allRecords;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @tagTree.
  ///
  /// In zh, this message translates to:
  /// **'树形标签'**
  String get tagTree;

  /// No description provided for @tagFlat.
  ///
  /// In zh, this message translates to:
  /// **'平铺标签'**
  String get tagFlat;

  /// No description provided for @editTags.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get editTags;

  /// No description provided for @addTag.
  ///
  /// In zh, this message translates to:
  /// **'添加标签'**
  String get addTag;

  /// No description provided for @tagName.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagName;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @layoutMode.
  ///
  /// In zh, this message translates to:
  /// **'布局模式'**
  String get layoutMode;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In zh, this message translates to:
  /// **'剪切'**
  String get cut;

  /// No description provided for @paste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// No description provided for @syncConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步冲突 ({count})'**
  String syncConflictTitle(Object count);

  /// No description provided for @noConflicts.
  ///
  /// In zh, this message translates to:
  /// **'暂无冲突'**
  String get noConflicts;

  /// No description provided for @hasConflict.
  ///
  /// In zh, this message translates to:
  /// **'有冲突'**
  String get hasConflict;

  /// No description provided for @recordConflict.
  ///
  /// In zh, this message translates to:
  /// **'笔记冲突'**
  String get recordConflict;

  /// No description provided for @metaConflict.
  ///
  /// In zh, this message translates to:
  /// **'元数据冲突'**
  String get metaConflict;

  /// No description provided for @recordContentUnchangedMetaConflict.
  ///
  /// In zh, this message translates to:
  /// **'笔记内容未改变, 仅元数据冲突. 请选择保留哪一侧的修改.'**
  String get recordContentUnchangedMetaConflict;

  /// No description provided for @conflictRemoteVersion.
  ///
  /// In zh, this message translates to:
  /// **'远端版本'**
  String get conflictRemoteVersion;

  /// No description provided for @conflictLocalModified.
  ///
  /// In zh, this message translates to:
  /// **'本地修改'**
  String get conflictLocalModified;

  /// No description provided for @keepRemote.
  ///
  /// In zh, this message translates to:
  /// **'保留远端'**
  String get keepRemote;

  /// No description provided for @keepLocal.
  ///
  /// In zh, this message translates to:
  /// **'保留本地'**
  String get keepLocal;

  /// No description provided for @orientationHorizontal.
  ///
  /// In zh, this message translates to:
  /// **'横向排列'**
  String get orientationHorizontal;

  /// No description provided for @orientationVertical.
  ///
  /// In zh, this message translates to:
  /// **'竖向排列'**
  String get orientationVertical;

  /// No description provided for @upgradeChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查...'**
  String get upgradeChecking;

  /// No description provided for @upgradeCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查失败'**
  String get upgradeCheckFailed;

  /// No description provided for @upgradeUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本 ✓'**
  String get upgradeUpToDate;

  /// No description provided for @upgradeAvailable.
  ///
  /// In zh, this message translates to:
  /// **'有新版本 {version}'**
  String upgradeAvailable(Object version);

  /// No description provided for @upgradeCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本: v{current} → 最新: {latest}'**
  String upgradeCurrentVersion(Object current, Object latest);

  /// No description provided for @upgradeChangelog.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get upgradeChangelog;

  /// No description provided for @upgradeNoChangelog.
  ///
  /// In zh, this message translates to:
  /// **'(无)'**
  String get upgradeNoChangelog;

  /// No description provided for @upgradeCopyDownloadUrl.
  ///
  /// In zh, this message translates to:
  /// **'复制下载链接'**
  String get upgradeCopyDownloadUrl;

  /// No description provided for @upgradeDownloadCopied.
  ///
  /// In zh, this message translates to:
  /// **'下载链接已复制: {url}'**
  String upgradeDownloadCopied(Object url);

  /// No description provided for @upgradeIOS.
  ///
  /// In zh, this message translates to:
  /// **'iOS 端需通过 App Store 更新'**
  String get upgradeIOS;

  /// No description provided for @upgradeServerUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器: {url}'**
  String upgradeServerUrl(Object url);

  /// No description provided for @upgradeDownloadAndInstall.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装'**
  String get upgradeDownloadAndInstall;

  /// No description provided for @upgradeReinstall.
  ///
  /// In zh, this message translates to:
  /// **'重新安装当前版本'**
  String get upgradeReinstall;

  /// No description provided for @upgradeDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载...'**
  String get upgradeDownloading;

  /// No description provided for @upgradeDownloadSuccess.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get upgradeDownloadSuccess;

  /// No description provided for @upgradeDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get upgradeDownloadFailed;

  /// No description provided for @switchToPad.
  ///
  /// In zh, this message translates to:
  /// **'切换到平板模式'**
  String get switchToPad;

  /// No description provided for @switchToPhone.
  ///
  /// In zh, this message translates to:
  /// **'切换到手机模式'**
  String get switchToPhone;

  /// No description provided for @switchToDesktop.
  ///
  /// In zh, this message translates to:
  /// **'切换到桌面模式'**
  String get switchToDesktop;

  /// No description provided for @modeDesktop.
  ///
  /// In zh, this message translates to:
  /// **'桌面模式'**
  String get modeDesktop;

  /// No description provided for @modePad.
  ///
  /// In zh, this message translates to:
  /// **'平板模式'**
  String get modePad;

  /// No description provided for @modePhone.
  ///
  /// In zh, this message translates to:
  /// **'手机模式'**
  String get modePhone;

  /// No description provided for @rememberOpenTabs.
  ///
  /// In zh, this message translates to:
  /// **'记住上次打开的记录'**
  String get rememberOpenTabs;

  /// No description provided for @rememberOpenTabsDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动时恢复上次关闭时的 tab 和选中状态'**
  String get rememberOpenTabsDesc;

  /// No description provided for @reminderTasks.
  ///
  /// In zh, this message translates to:
  /// **'提醒任务'**
  String get reminderTasks;

  /// No description provided for @noReminderTasks.
  ///
  /// In zh, this message translates to:
  /// **'暂无提醒任务'**
  String get noReminderTasks;

  /// No description provided for @unnamedTask.
  ///
  /// In zh, this message translates to:
  /// **'未命名任务'**
  String get unnamedTask;

  /// No description provided for @notSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get notSet;

  /// No description provided for @repeatOnce.
  ///
  /// In zh, this message translates to:
  /// **'单次'**
  String get repeatOnce;

  /// No description provided for @repeatWeekly.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In zh, this message translates to:
  /// **'每月'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In zh, this message translates to:
  /// **'每年'**
  String get repeatYearly;

  /// No description provided for @editReminder.
  ///
  /// In zh, this message translates to:
  /// **'编辑提醒'**
  String get editReminder;

  /// No description provided for @taskName.
  ///
  /// In zh, this message translates to:
  /// **'任务名称'**
  String get taskName;

  /// No description provided for @repeat.
  ///
  /// In zh, this message translates to:
  /// **'重复'**
  String get repeat;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @addReminder.
  ///
  /// In zh, this message translates to:
  /// **'添加提醒'**
  String get addReminder;

  /// No description provided for @weekdays.
  ///
  /// In zh, this message translates to:
  /// **'周一|周二|周三|周四|周五|周六|周日'**
  String get weekdays;

  /// No description provided for @calendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get calendar;

  /// No description provided for @noRemindersToday.
  ///
  /// In zh, this message translates to:
  /// **'当天无提醒'**
  String get noRemindersToday;

  /// No description provided for @reminder.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get reminder;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今'**
  String get today;

  /// No description provided for @repeatMonthlyTime.
  ///
  /// In zh, this message translates to:
  /// **'每月{day}日 {time}'**
  String repeatMonthlyTime(int day, String time);

  /// No description provided for @repeatYearlyTime.
  ///
  /// In zh, this message translates to:
  /// **'每年{month}月{day}日 {time}'**
  String repeatYearlyTime(int month, int day, String time);

  /// No description provided for @reminderChannel.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get reminderChannel;

  /// No description provided for @reminderChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'笔记任务提醒'**
  String get reminderChannelDesc;

  /// No description provided for @reminderDueBody.
  ///
  /// In zh, this message translates to:
  /// **'该提醒已到时间'**
  String get reminderDueBody;

  /// No description provided for @searchRecords.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get searchRecords;

  /// No description provided for @searchHistory.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get searchHistory;

  /// No description provided for @clearSearchHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearSearchHistory;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'无匹配结果'**
  String get searchNoResults;

  /// No description provided for @unitYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get unitYear;

  /// No description provided for @unitMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get unitMonth;

  /// No description provided for @unitDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get unitDay;

  /// No description provided for @unitHour.
  ///
  /// In zh, this message translates to:
  /// **'时'**
  String get unitHour;

  /// No description provided for @unitMinute.
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get unitMinute;

  /// No description provided for @atLeastOneWeekday.
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一个星期'**
  String get atLeastOneWeekday;

  /// No description provided for @recycler.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get recycler;

  /// No description provided for @purgeRecyclerItem.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get purgeRecyclerItem;

  /// No description provided for @clearRecycler.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get clearRecycler;

  /// No description provided for @confirmClearRecycler.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空回收站吗？'**
  String get confirmClearRecycler;

  /// No description provided for @confirmPurgeRecycler.
  ///
  /// In zh, this message translates to:
  /// **'确定要彻底删除吗？删除后无法恢复'**
  String get confirmPurgeRecycler;

  /// No description provided for @recyclerAutoClearHint.
  ///
  /// In zh, this message translates to:
  /// **'回收站条目将在 {days} 天后自动清理'**
  String recyclerAutoClearHint(int days);

  /// No description provided for @recyclerRestored.
  ///
  /// In zh, this message translates to:
  /// **'已还原 {name}'**
  String recyclerRestored(String name);

  /// No description provided for @recyclerRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'还原失败'**
  String get recyclerRestoreFailed;

  /// No description provided for @recyclerPurged.
  ///
  /// In zh, this message translates to:
  /// **'已彻底删除'**
  String get recyclerPurged;

  /// No description provided for @recyclerCleared.
  ///
  /// In zh, this message translates to:
  /// **'回收站已清空'**
  String get recyclerCleared;

  /// No description provided for @importExport.
  ///
  /// In zh, this message translates to:
  /// **'导入导出'**
  String get importExport;

  /// No description provided for @exportMd.
  ///
  /// In zh, this message translates to:
  /// **'导出 MD'**
  String get exportMd;

  /// No description provided for @exportSelectFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择导出目标文件夹'**
  String get exportSelectFolder;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get exportFailed;

  /// No description provided for @exportNoRecords.
  ///
  /// In zh, this message translates to:
  /// **'该文件夹下没有笔记'**
  String get exportNoRecords;

  /// No description provided for @exportingProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在导出 {done}/{total}'**
  String exportingProgress(int done, int total);

  /// No description provided for @exportEncryptedTitle.
  ///
  /// In zh, this message translates to:
  /// **'文档已加密，请输入密码'**
  String get exportEncryptedTitle;

  /// No description provided for @exportSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get exportSkip;

  /// No description provided for @exportCancelled.
  ///
  /// In zh, this message translates to:
  /// **'导出已取消'**
  String get exportCancelled;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @shareDays.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get shareDays;

  /// No description provided for @shareHours.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get shareHours;

  /// No description provided for @shareExpireHint.
  ///
  /// In zh, this message translates to:
  /// **'链接有效期'**
  String get shareExpireHint;

  /// No description provided for @shareCreating.
  ///
  /// In zh, this message translates to:
  /// **'正在创建分享链接…'**
  String get shareCreating;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败'**
  String get shareFailed;

  /// No description provided for @shareInvalidExpire.
  ///
  /// In zh, this message translates to:
  /// **'有效期需大于 0 且不超过 30 天'**
  String get shareInvalidExpire;

  /// No description provided for @shareLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'链接已复制到剪贴板'**
  String get shareLinkCopied;

  /// No description provided for @exportCompleted.
  ///
  /// In zh, this message translates to:
  /// **'导出完成：成功 {success} 篇，跳过 {skipped} 篇'**
  String exportCompleted(int success, int skipped);

  /// No description provided for @exportOpenFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get exportOpenFolder;

  /// No description provided for @outline.
  ///
  /// In zh, this message translates to:
  /// **'大纲'**
  String get outline;

  /// No description provided for @noHeadings.
  ///
  /// In zh, this message translates to:
  /// **'暂无标题'**
  String get noHeadings;

  /// No description provided for @wordCount.
  ///
  /// In zh, this message translates to:
  /// **'字数'**
  String get wordCount;

  /// No description provided for @todoList.
  ///
  /// In zh, this message translates to:
  /// **'待办'**
  String get todoList;

  /// No description provided for @table.
  ///
  /// In zh, this message translates to:
  /// **'表格'**
  String get table;

  /// No description provided for @insertTime.
  ///
  /// In zh, this message translates to:
  /// **'插入时间'**
  String get insertTime;

  /// No description provided for @recordInfo.
  ///
  /// In zh, this message translates to:
  /// **'笔记信息'**
  String get recordInfo;

  /// No description provided for @clearLogs.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get clearLogs;

  /// No description provided for @confirmClearLogs.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有日志吗？此操作不可恢复。'**
  String get confirmClearLogs;

  /// No description provided for @logsCleared.
  ///
  /// In zh, this message translates to:
  /// **'日志已清空'**
  String get logsCleared;

  /// No description provided for @clearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空失败'**
  String get clearFailed;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @filterLevel.
  ///
  /// In zh, this message translates to:
  /// **'筛选级别'**
  String get filterLevel;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// No description provided for @addAccount.
  ///
  /// In zh, this message translates to:
  /// **'添加账号'**
  String get addAccount;

  /// No description provided for @switchAccountFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换账号失败'**
  String get switchAccountFailed;

  /// No description provided for @loadingUserData.
  ///
  /// In zh, this message translates to:
  /// **'用户数据加载中'**
  String get loadingUserData;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
