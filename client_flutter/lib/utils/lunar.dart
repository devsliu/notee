/// 农历与节气计算工具。
///
/// 支持 1900-2100 年。内置 lunarInfo 数组（每年一个整数编码农历信息），
/// 节气使用经典公式法计算。
library;

/// 1900-2100 年农历信息表。
/// 每个整数的低 4 位 = 闰月月份（0 表示无闰月），
/// 中间 12 位 = 各月大小（1=大月30天，0=小月29天），从高到低为正月到腊月，
/// 若有闰月，最高位之后再加一位表示闰月大小。
///
/// 该表为经典农历算法标准数据。
const List<int> _lunarInfo = [
  0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2, // 1900-1909
  0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977, // 1910-1919
  0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, // 1920-1929
  0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950, // 1930-1939
  0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557, // 1940-1949
  0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0, // 1950-1959
  0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, // 1960-1969
  0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6, // 1970-1979
  0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570, // 1980-1989
  0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0, // 1990-1999
  0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, // 2000-2009
  0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930, // 2010-2019
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530, // 2020-2029
  0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, // 2030-2039
  0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, // 2040-2049
  0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0, // 2050-2059
  0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4, // 2060-2069
  0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, // 2070-2079
  0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, // 2080-2089
  0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252, // 2090-2099
  0x0d520, // 2100
];

const List<String> _gan = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const List<String> _zhi = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
const List<String> _zodiac = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];
const List<String> _lunarMonthNames = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];
const List<String> _lunarDayNames = [
  '初一',
  '初二',
  '初三',
  '初四',
  '初五',
  '初六',
  '初七',
  '初八',
  '初九',
  '初十',
  '十一',
  '十二',
  '十三',
  '十四',
  '十五',
  '十六',
  '十七',
  '十八',
  '十九',
  '二十',
  '廿一',
  '廿二',
  '廿三',
  '廿四',
  '廿五',
  '廿六',
  '廿七',
  '廿八',
  '廿九',
  '三十',
];

/// 24节气名称（按公历年度顺序，从小寒开始）。
const List<String> _solarTerms = [
  '小寒',
  '大寒',
  '立春',
  '雨水',
  '惊蛰',
  '春分',
  '清明',
  '谷雨',
  '立夏',
  '小满',
  '芒种',
  '夏至',
  '小暑',
  '大暑',
  '立秋',
  '处暑',
  '白露',
  '秋分',
  '寒露',
  '霜降',
  '立冬',
  '小雪',
  '大雪',
  '冬至',
];

/// 24节气在 20 世纪的 C 值（公式法常数）。
const List<double> _c20 = [
  6.11,
  20.84,
  4.6295,
  19.4599,
  6.3826,
  21.4155,
  5.59,
  20.888,
  6.318,
  21.86,
  6.5,
  22.2,
  7.928,
  23.65,
  8.35,
  23.95,
  8.44,
  23.822,
  9.098,
  24.218,
  8.218,
  23.08,
  7.9,
  22.6,
];

/// 24节气在 21 世纪的 C 值（公式法常数）。
const List<double> _c21 = [
  5.4055,
  20.12,
  3.87,
  18.73,
  5.63,
  20.646,
  4.81,
  20.1,
  5.52,
  21.04,
  5.678,
  21.37,
  7.108,
  22.83,
  7.5,
  23.13,
  7.646,
  23.042,
  8.318,
  23.438,
  7.438,
  22.36,
  7.18,
  21.94,
];

/// 农历日期信息。
class LunarDate {
  /// 农历年（数字）
  final int year;

  /// 农历月（1-12）
  final int month;

  /// 农历日（1-30）
  final int day;

  /// 是否闰月
  final bool isLeap;

  /// 干支纪年（如"甲辰"）
  final String ganZhi;

  /// 生肖（如"龙"）
  final String zodiac;

  /// 农历月中文（如"正月"、"闰二月"）
  final String monthText;

  /// 农历日中文（如"十五"）
  final String dayText;

  /// 当天节气名称（无则为 null）
  final String? solarTerm;

  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    required this.isLeap,
    required this.ganZhi,
    required this.zodiac,
    required this.monthText,
    required this.dayText,
    this.solarTerm,
  });

  /// 日历单元格显示文字：优先节气，其次农历日（初一显示月名）。
  String get cellText {
    if (solarTerm != null) return solarTerm!;
    if (day == 1) return '${isLeap ? '闰' : ''}$monthText月';
    return dayText;
  }

  @override
  String toString() => '$ganZhi年${isLeap ? "闰" : ""}$monthText月$dayText';
}

/// 返回该年农历总天数。
int _lunarYearDays(int year) {
  int sum = 348; // 12 × 29
  for (int i = 0x8000; i > 0x8; i >>= 1) {
    if ((_lunarInfo[year - 1900] & i) != 0) sum += 1;
  }
  return sum + _leapDays(year);
}

/// 返回该年闰月天数（无闰月返回 0）。
int _leapDays(int year) {
  if (leapMonth(year) == 0) return 0;
  return (_lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
}

/// 返回该年闰月月份（0 表示无闰月）。
int leapMonth(int year) => _lunarInfo[year - 1900] & 0xf;

/// 返回该年某月天数（month 1-12）。
int _monthDays(int year, int month) {
  return (_lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;
}

/// 农历转公历。
///
/// [lunarYear] 农历年（1900-2100），[lunarMonth] 农历月（1-12），
/// [lunarDay] 农历日（1-30）。[isLeap] 表示是否闰月。
/// 若该月没有该日（小月无30），自动取当月最后一天。
DateTime lunarToSolar(int lunarYear, int lunarMonth, int lunarDay, {bool isLeap = false}) {
  // 基准：1900-01-31 = 农历 1900 年正月初一
  final base = DateTime(1900, 1, 31);
  int offset = 0;

  // 累加整年
  for (int y = 1900; y < lunarYear; y++) {
    offset += _lunarYearDays(y);
  }

  // 累加整月（处理闰月）
  final leap = leapMonth(lunarYear);
  for (int m = 1; m < lunarMonth; m++) {
    offset += _monthDays(lunarYear, m);
    if (m == leap) {
      offset += _leapDays(lunarYear);
    }
  }
  // 若取闰月，需先跳过同月的正常月
  if (isLeap && leap == lunarMonth) {
    offset += _monthDays(lunarYear, lunarMonth);
  }

  // 日
  final maxDay = isLeap ? _leapDays(lunarYear) : _monthDays(lunarYear, lunarMonth);
  offset += lunarDay.clamp(1, maxDay) - 1;

  return base.add(Duration(days: offset));
}

/// 公历转农历。
LunarDate solarToLunar(DateTime date) {
  // 以 1900-01-31 为基准（农历 1900 年正月初一）
  final baseDate = DateTime(1900, 1, 31);
  int offset = DateTime(date.year, date.month, date.day).difference(baseDate).inDays;

  int year = 1900;
  int daysInYear;
  while (year < 2101 && offset > 0) {
    daysInYear = _lunarYearDays(year);
    if (offset < daysInYear) break;
    offset -= daysInYear;
    year++;
  }

  int leap = leapMonth(year);
  bool isLeap = false;
  int month = 1;
  int daysInMonth;

  for (month = 1; month < 13 && offset > 0; month++) {
    if (leap > 0 && month == leap + 1 && !isLeap) {
      month--;
      isLeap = true;
      daysInMonth = _leapDays(year);
    } else {
      daysInMonth = _monthDays(year, month);
    }

    if (isLeap && month == leap + 1) isLeap = false;
    if (offset < daysInMonth) break;
    offset -= daysInMonth;
  }

  int day = offset + 1;

  // 干支纪年：以立春为界的简化版，这里用农历年直接算
  int ganZhiIndex = (year - 1900 + 36) % 60;
  String ganZhi = '${_gan[ganZhiIndex % 10]}${_zhi[ganZhiIndex % 12]}';
  String zodiac = _zodiac[(year - 4) % 12];

  String monthText = isLeap ? '闰$_lunarMonthNames[month - 1]' : _lunarMonthNames[month - 1];
  String dayText = _lunarDayNames[day - 1];

  // 节气
  String? solarTerm = _getSolarTerm(date);

  return LunarDate(
    year: year,
    month: month,
    day: day,
    isLeap: isLeap,
    ganZhi: ganZhi,
    zodiac: zodiac,
    monthText: monthText,
    dayText: dayText,
    solarTerm: solarTerm,
  );
}

/// 21世纪节气日期修正表：key="年份-节气序号"，value=修正天数。
/// 公式法对绝大多数年份准确，仅少数年份需 ±1 修正。
const Map<String, int> _solarTermFix21 = {
  '2026-6': 1, // 清明
  '2084-6': 1, // 清明
};

/// 20世纪节气日期修正表。
const Map<String, int> _solarTermFix20 = {};

/// 计算某日的节气（无则返回 null）。
///
/// 使用经典公式法：日期 = [Y×0.2422 + C] - L
/// 其中 Y = 年份后两位，L = 闰年数（floor(Y/4)），C 为节气常数。
/// 精确匹配，仅对已知误差年份做修正。
String? _getSolarTerm(DateTime date) {
  int year = date.year;
  if (year < 1900 || year > 2100) return null;

  // 1月、2月的节气属于上一年的节气序列
  int y = (date.month <= 2) ? year - 1 : year;
  int Y = y % 100;
  int L = Y ~/ 4;

  // 根据年份选择 C 值表和修正表
  final cTable = (y < 2000) ? _c20 : _c21;
  final fixTable = (y < 2000) ? _solarTermFix20 : _solarTermFix21;

  // 只检查当前月份的两个节气
  final monthIdx = date.month - 1;
  for (int k = 0; k < 2; k++) {
    final i = monthIdx * 2 + k;
    final c = cTable[i];
    var d = (Y * 0.2422 + c).floor() - L;

    // 应用已知修正
    final fixKey = '$y-$i';
    d += fixTable[fixKey] ?? 0;

    if (date.day == d) {
      return _solarTerms[i];
    }
  }
  return null;
}
