import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle, TextInputFormatter, FilteringTextInputFormatter;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // allows async code in main

  // 1️ Create Calculate instance
  //final calc = Calculate();

  // 2️ Load saved period data
  //await calc.loadData();

  // 3️ Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Calculate()..loadData(),),
        ChangeNotifierProvider(
          create: (_) => CycleDataProvider()..load(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainNavigationBar(),
    );
  }
}

// list of files based on phase 
const Map<String, String> phaseJsonFiles = {
  'Menstruation': 'assets/Menstrual_Phase.json',
  'Follicular': 'assets/Follicular_Phase.json',
  'Ovulation': 'assets/Ovulation_Phase.json',
  'Early Luteal': 'assets/Early_Luteal_Phase.json',
  'Late Luteal': 'assets/Late_Luteal_Phase.json',
  // 'All Phases': 'assets/All_Phases.json'
};


class PhaseDayInfo {
  final String phase;
  final int dayOfPhase;
  final Map<String, dynamic> values;

  PhaseDayInfo({
    required this.phase,
    required this.dayOfPhase,
    required this.values,
  });

  double? getDouble(String field) {
    final raw = values[field];
    if (raw == null) return null;
    return double.tryParse(raw.toString()); // why double and not string
  }
}



class CycleDataProvider extends ChangeNotifier {
  Map<String, List<Map<String, dynamic>>> _data = {};
  bool _loaded = false;
  String _selectedField = 'Phase Info';

  bool get isLoaded => _loaded;
  String get selectedField => _selectedField;


// go through this and understand cause wtf
List<PhaseDayInfo> getAllPhaseDays(String phase) {
  final phaseData = _data[phase];
  if (phaseData == null || phaseData.isEmpty) return [];

  return List.generate(
    phaseData.length,
    (index) => PhaseDayInfo(
      phase: phase,
      dayOfPhase: index + 1,
      values: phaseData[index],
    ),
  );
}


Future<void> load() async {
    if (_loaded) return;

    final Map<String, List<Map<String, dynamic>>> result = {};
    final Map<String, List<Map<String, dynamic>>> _allphases = {};

//decoding each json file
    for (final entry in phaseJsonFiles.entries) {
      final jsonString = await rootBundle.loadString(entry.value);
      final List<dynamic> decoded = json.decode(jsonString);
      result[entry.key] = decoded.cast<Map<String, dynamic>>();
    }

    _data = result;
    _loaded = true;
    notifyListeners();
  }
  void selectField(String field) {
    _selectedField = field;
    notifyListeners();
  }


  String getPhaseInfo({
    required String phase,
    required int dayOfPhase,
    required String field,
  }) {
    // one of the json files
    final infoPerPhase = _data[phase];
    if (infoPerPhase == null || infoPerPhase.isEmpty) return 'No data';

//in functie de index iti deschide fiecare zi din acel phase json file 
    final infoPerDayInPhase = (dayOfPhase - 1).clamp(0, infoPerPhase.length - 1); // toata ziua
    return infoPerPhase[infoPerDayInPhase][field]?.toString() ?? 'No data'; // fiecare cell din row ul ala
  }

//   PhaseDayInfo? getPhaseDayInfo({
//   required String phase,
//   required int dayOfPhase,
// }) {
//   final infoPerPhase = _data[phase];
//   if (infoPerPhase == null || infoPerPhase.isEmpty) return null;

//   final index = (dayOfPhase - 1).clamp(0, infoPerPhase.length - 1);

//   return PhaseDayInfo(
//     phase: phase,
//     dayOfPhase: dayOfPhase,
//     values: infoPerPhase[index],
//   );
// }

}

class Calculate extends ChangeNotifier {
  DateTime? nextPeriodDate;
  int? difference;
  String? phase;
  int? dayofphase;

  int cycleLength = 28;
  int periodLength = 5;

  DateTime? lastPeriodDate;

  //save data

  Future<void> saveData(DateTime lastPeriodDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPeriodDate', lastPeriodDate.toIso8601String());
    await prefs.setInt('cycleLength', cycleLength);
    await prefs.setInt('periodLength', periodLength);

    this.lastPeriodDate = lastPeriodDate;

    // recompute next period & day
    calculateNextPeriod(lastPeriodDate, cycleLength);
    calculateDayOfCycle(lastPeriodDate);
    determinePhase(
      cycleDay: difference!,
      cycleLength: cycleLength,
      periodLength: periodLength,
    );

    notifyListeners();

  }

  Future<void> loadData() async {
  final prefs = await SharedPreferences.getInstance();

  String? dateString = prefs.getString('lastPeriodDate');
  int? savedCycleLength = prefs.getInt('cycleLength');
  int? savedPeriodLength = prefs.getInt('periodLength');

  if (dateString != null && savedCycleLength != null && savedPeriodLength != null) {
    lastPeriodDate = DateTime.parse(dateString);
    cycleLength = savedCycleLength;
    periodLength = savedPeriodLength;

    final today = DateTime.now();
    difference = today.difference(lastPeriodDate!).inDays + 1;

    determinePhase(
      cycleDay: difference!,
      cycleLength: cycleLength,
      periodLength: periodLength,
    );

    nextPeriodDate = lastPeriodDate!.add(Duration(days: cycleLength));

    notifyListeners();
  }
}

  Future<void> updateLastPeriod({
    required DateTime lastPeriodDate,
    required int periodLength,
    required int cycleLength,
  }) async {
    // Update provider state
    this.lastPeriodDate = lastPeriodDate;
    this.periodLength = periodLength;
    this.cycleLength = cycleLength;

    // Recompute
    calculateNextPeriod(lastPeriodDate, cycleLength);
    calculateDayOfCycle(lastPeriodDate);
    determinePhase(
      cycleDay: difference!,
      cycleLength: cycleLength,
      periodLength: periodLength,
    );

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPeriodDate', lastPeriodDate.toIso8601String());
    await prefs.setInt('periodLength', periodLength);
    await prefs.setInt('cycleLength', cycleLength);

    notifyListeners();
  }

  //so the function for the lengths of the phases that changes the length of the cirle is based on the original valyes, 28 and 7
  //have to figure out a way to update them with the input values from the user

  void updateCycleLength(int newLength) {
    cycleLength = newLength;
    notifyListeners(); // This tells PlaceholderPage to rebuild
  }

  void updateperiodLength(int newLength) {
    periodLength = newLength;
    notifyListeners(); // This tells PlaceholderPage to rebuild
  }

  void calculateNextPeriod(DateTime lastPeriodDate, int cycleLength) {
    nextPeriodDate = lastPeriodDate.add(Duration(days: cycleLength));
    notifyListeners();
  }
  
  void calculateDayOfCycle(DateTime lastPeriodDate) {
    final today = DateTime.now();
    difference = today.difference(lastPeriodDate).inDays + 1;
    notifyListeners();
  }
  // Future <void> calculatePhase() async {
  //   if (difference == null) return;
  //   final cycleData = await loadCycleData();
  //   final entry = cycleData.firstWhere(
  //     (e) => e["Day"] == difference,
  //     orElse: () => {"Phase": "Unknown"},
  //   );
  //   phase = entry["Phase"];
  //   notifyListeners();
  // }

  void determinePhase({
    required int cycleDay,
    required int cycleLength,
    required int periodLength,
    // final String? phase,
    }) {
        int ovulationDay = cycleLength - 14;

        if (cycleDay <= periodLength) {
          phase = 'Menstruation';
          dayofphase = cycleDay;
        } else if (cycleDay < ovulationDay) {
          phase  =  'Follicular';
          dayofphase = cycleDay - periodLength;
        } else if (cycleDay == ovulationDay) {
          phase = 'Ovulation';
          dayofphase = 1; // shouldnt this be 1
        } else if (cycleDay <= ovulationDay + 6) {
          phase = 'Early Luteal';
          dayofphase = cycleDay - ovulationDay;
        } else {
          phase = 'Late Luteal';
          dayofphase = cycleDay - ovulationDay - 6;
        }
        // return phase!;
        //notifyListeners();
    }

    Map<String, int> getPhaseForCycleDay({required int cycleDay}) {
      int ovulationDay = cycleLength - 14;

      if (cycleDay <= periodLength) {
        return {"phase": 0, "day": cycleDay}; // Menstruation
      } else if (cycleDay < ovulationDay) {
        return {"phase": 1, "day": cycleDay - periodLength}; // Follicular
      } else if (cycleDay == ovulationDay) {
        return {"phase": 2, "day": 1}; // Ovulation
      } else if (cycleDay <= ovulationDay + 6) {
        return {"phase": 3, "day": cycleDay - ovulationDay}; // Early Luteal
      } else {
        return {"phase": 4, "day": cycleDay - ovulationDay - 6}; // Late Luteal
      }
    }

    String phaseNameFromIndex(int i) {
      return [
        'Menstruation',
        'Follicular',
        'Ovulation',
        'Early Luteal',
        'Late Luteal',
      ][i];
    }


    List<int> get getUpdatedPhaseLengths {
    int ovulationDay = cycleLength - 14;
    int menstruation = periodLength;

    int follicular = (ovulationDay - periodLength - 1).clamp(1, 31);
    int ovulation = 1;
    int earlyLuteal = 6;
    int lateLuteal = (cycleLength - (menstruation + follicular + ovulation + earlyLuteal)).clamp(1, 35);
    
    //clamp means that, if the value is lower than 1 it returns 1 and if it's higher than the second value it returns that value

    return [menstruation, follicular, ovulation, earlyLuteal, lateLuteal];
  }

  }



class MainNavigationBar extends StatefulWidget {
  const MainNavigationBar({super.key});

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CustomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(child:
        Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(10, 0, 0, 0.358),
            offset: Offset(0, -4),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavButton(
            label: 'Log Page', //should we just call it log? since the others don't have page in their name
            // icon: 'assets/images/vector.svg',
            icon: Icons.add, // icon for tabs design
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _NavButton(
            label: 'Home',
            // icon: 'assets/images/vector.svg',
            // icon: Icon(Icons.info).toString(),
            icon: Icons.home,
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _NavButton(
            label: 'Daily Tips',
            // icon: 'assets/images/vector.svg',
            icon: Icons.person,
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          _NavButton(
            label: 'Calendar',
            // icon: 'assets/images/vector.svg',
            icon: Icons.calendar_month_rounded,
            isSelected: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),
        ],
      ),
    ),
    );
  }
}


class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF303437)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(48),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color:
                isSelected
                    ? const Color.fromRGBO(242, 243, 244, 1)
                    : Color.fromRGBO(24, 18, 58, 0.5),
              ),
            
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  color: Color.fromRGBO(242, 243, 244, 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _MainNavigationBarState extends State<MainNavigationBar> {

  //this changes which page opens first
  int _selectedIndex = 1;

  // Top-level pages only
  List<Widget> get _pages => [
  LogPage(onSubmit: () => _onItemTapped(1)),
  const PlaceholderPage(),
  const DailyTipsPage(),
  const CalendarPage(),
];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    //appBar: 
    // AppBar(
    // title: const Text("Log your Period Details!"),
    // ),
    body: _pages[_selectedIndex],
    bottomNavigationBar: CustomNavigationBar(
      selectedIndex: _selectedIndex,
      onItemSelected: _onItemTapped,
    ),
  );
}
}

class NavigationState extends ChangeNotifier {
  int index = 0;

  void goTo(int i) {
    index = i;
    notifyListeners();
  }
}


// whole first page
class LogPage extends StatelessWidget {
  final VoidCallback onSubmit;
  
  const LogPage({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Log your Period Details!"),
      ),
      body: SafeArea(child:
      SingleChildScrollView(
      child:
      Column(
      children: [
      LogCalendar(onSubmit: onSubmit),
      Align(
        alignment: Alignment.bottomRight,
        child:
      Image.asset(
            'assets/clip-woman-doing-exercises.png',
            width: 200,
            height: 200,
          ),
      ),
    //         SvgPicture.asset(
    //       'clip-woman-doing-exercises.svg',
    //           semanticsLabel: 'Exercise Woman',
    //  ),
      ],
      ),
      ),
      ),
    );
    
    
    // appBar: 
    // AppBar(
    // title: const Text("Log your Period Details!"),
    // ),
    // return LogCalendar(onSubmit: onSubmit);
  }
}

//calendar
class LogCalendar extends StatefulWidget {
  final VoidCallback onSubmit;

  const LogCalendar({super.key, required this.onSubmit});
  @override
  State<LogCalendar> createState() => _LogCalendarState();
}

class _LogCalendarState extends State<LogCalendar> {
  DateTime? selectedDate;
  DateTime now = new DateTime.now();

  final TextEditingController periodLengthController = TextEditingController();
  final TextEditingController cycleLengthController = TextEditingController();

  Future<void> savePeriodData() async {
    if (selectedDate == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('lastPeriodDate', selectedDate!.toIso8601String());
    await prefs.setInt('periodLength', int.tryParse(periodLengthController.text) ?? 5);
    await prefs.setInt('cycleLength', int.tryParse(cycleLengthController.text) ?? 28);
  }

  Future<void> loadPeriodData() async {
    final prefs = await SharedPreferences.getInstance();

    String? dateString = prefs.getString('lastPeriodDate');
    int? periodLength = prefs.getInt('periodLength');
    int? cycleLength = prefs.getInt('cycleLength');

    if (dateString != null) {
      setState(() {
        selectedDate = DateTime.parse(dateString);
        periodLengthController.text = periodLength?.toString() ?? '5';
        cycleLengthController.text = cycleLength?.toString() ?? '28';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadPeriodData();
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1999),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    setState(() {
      selectedDate = pickedDate;
    });
  }

  @override
  void dispose() {
    periodLengthController.dispose();
    cycleLengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      //padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      padding: const EdgeInsets.all(8), //how much space there is from the edges
      child:
        Column(
          mainAxisSize: MainAxisSize.min,
          //spac
          children:<Widget> [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("When was the start of your last period?", 
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w700,
                height: 2,
                ),),
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                selectedDate != null
                    ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                    : 'No date selected',
                    style: TextStyle(
                      color: const Color(0xFF8C8888),
                      fontSize: 16,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w700,
                      height: 2,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: SelectButton(
                    label: 'Select Date',
                    onPressed: _selectDate,
                  ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(8.0),
              child:
            TextBox(
                  title: "Average menstruation length (days):",
                  hint: "Enter number of days",
                  controller: periodLengthController,
                ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(8.0),
              child:
            TextBox(
                  title: "Average cycle length (days):",
                  hint: "Enter number of days",
                  controller: cycleLengthController,
                ),
            ),
            
            SelectButton(
                  label: 'Submit',
                  onPressed: () async {
                    if (selectedDate == null) return;

                    final int periodLength =
                        int.tryParse(periodLengthController.text) ?? 5;
                    final int cycleLength =
                        int.tryParse(cycleLengthController.text) ?? 28;

                    final calc = context.read<Calculate>();

                    // Update provider & save data in one call
                    await calc.updateLastPeriod(
                      lastPeriodDate: selectedDate!,
                      periodLength: periodLength,
                      cycleLength: cycleLength,
                    );

                    widget.onSubmit(); // optional callback
                  },

                ),
          ],
        
        ),
    
    );
  }
  //child: const Text("Submit"),

  }



class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<Calculate>();
    final phaseLengths = calc.getUpdatedPhaseLengths;

    final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final newcyclelength = calc.updateCycleLength;
    final newperiodlength = calc.updateperiodLength;
    String formattedDate = DateFormat('EEEE, MMM d').format(DateTime.now());


    //final double totalDaysInCycle = calc.cycleLength.toDouble();

    // Calculate progress for the white dot
    // (Today's day / Total days)
    //final double progress = (calc.cycleDay / calc.cycleLength).clamp(0.0, 1.0);

    final cycleData = context.watch<CycleDataProvider>();

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculate where the dot should sit (0.0 to 1.0)
    // If you are on Day 7 of 28, progress is 0.25 (exactly 1/4 of the way)
    final double totalDaysInCycle = (calc.cycleLength ?? 28).toDouble(); // Adjust based on your research
    final double currentDay = (calc.difference ?? 0).toDouble();
    final double progress =
        (currentDay / totalDaysInCycle).clamp(0.0, 1.0);

    //print('Current Phase Lengths: $currentPhaseLengths');

    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;
    final selectedField = cycleData.selectedField;

  final info = (phase != null && dayOfPhase != null)
    ? cycleData.getPhaseInfo(
        phase: phase,
        dayOfPhase: dayOfPhase,
        field: "Today's Recap",
      )
    : 'No data';

    return SingleChildScrollView(
      padding:const EdgeInsets.all(16),
      child:
      SafeArea(child:
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        //backgroundColor: Colors.white, - this doesnt work for some reason
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // const Text(
          //   'Cycle Overview',
          //   style: TextStyle(
          //     fontSize: 24,
          //     fontWeight: FontWeight.bold,
          //     color: Color.fromRGBO(54, 18, 58, 1),
          //   ),
          // ),

          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTapDown: (details) {
                  // Calculate the center of the 300x300 canvas
                  const center = Offset(150, 150);
                  final tapPos = details.localPosition;
                  
                  // Use atan2 to get the angle in radians
                  double angle = atan2(tapPos.dy - center.dy, tapPos.dx - center.dx);
                  
                  // Adjust angle so 0 is at the top (-pi/2)
                  angle = (angle + pi / 2) % (2 * pi);
                  if (angle < 0) angle += 2 * pi;

                  // Determine segment (5 segments = 2*pi / 5 = ~1.25 radians each)
                  int segmentIndex = (angle / (2 * pi / 5)).floor();

                  // Navigate based on segment
                  final List<Widget> pages = [
                    const MenstruationPage(),
                    const FolicularPage(),
                    const OvulationPage(),
                    const EarlyLutealPage(), 
                    const LateLutealPage(), 
                  ];

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => pages[segmentIndex]),
                  );
                },
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: CyclePainter(
                    // Use your real progress logic here: 
                    // (dayOfCycle / totalDays)
                    currentProgress: progress, 
                    // phaseLengths: context.read<Calculate>().getUpdatedPhaseLengths,
                    phaseLengths: phaseLengths,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Day ${difference ?? 1}", 
                    style: TextStyle(
                      color: const Color(0xFF303437),
                      fontSize: 24,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w700,
                      height: 1.46,
                      ),
                  ),
                  Text(
                    phase ?? "Menstruation", 
                    style: TextStyle(
                      color: const Color(0xFF303437),
                      fontSize: 24,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w700,
                      height: 1.46,
                      ),
                  ),
                  const SizedBox(height: 8), // Adds a little breathing room
                  Text(
                    formattedDate, 
                    style: TextStyle(
                      color: const Color(0xFF72777A),
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w500,
                      height: 1.33,
                      ),
                  ),
                  // SizedBox(height: 10),
                  // Positioned(
                  //   top: -80,   // Adjust these to get the exact "sit" you want
                  //   right: -5,
                  //   child: Image.asset(
                  //     'assets/girl-pointing.png',
                  //     width: 35, // Adjust size based on your asset
                  //   ),
                  // ),
                    ],
                  ),
                ],
              ),
          
          const SizedBox(height: 40),

          // _infoTile(
          //   title: 'Next Expected Period',
          //   value: nextPeriodDate != null
          //       ? '${nextPeriodDate.day}/${nextPeriodDate.month}/${nextPeriodDate.year} (+/- 5.3 days)'
          //       : 'Not calculated',
          //   icon: Icons.calendar_today,
          //   ),

          

          Stack(
          clipBehavior: Clip.none,
          children: [

          _infoTile(
            title: 'Next Expected Period',
            value: nextPeriodDate != null
                ? '${nextPeriodDate.day}/${nextPeriodDate.month}/${nextPeriodDate.year} (+/- 5.3 days)'
                : 'Not calculated',
            icon: Icons.calendar_month_rounded,
            ),
            
            Positioned(
              top: -90,   // Adjust these to get the exact "sit" you want
              right: -12,
              child: Image.asset(
                'assets/girl-sitting.png',
                width: 120, // Adjust size based on your asset
              ),
            ),
          ],
        ),
          
          // Next Period Card
          // _infoTile(
          //   title: 'Next Expected Period',
          //   value: nextPeriodDate != null
          //       ? '${nextPeriodDate.day}/${nextPeriodDate.month}/${nextPeriodDate.year}'
          //       : 'Not calculated',
          //   icon: Icons.calendar_today,
          // ),

          // Day of Cycle Card
          // _infoTile(
          //   title: 'Days Since Last Period',
          //   value: difference != null ? '$difference Days' : 'Pending',
          //   icon: Icons.timer,
          // ),

          //Current Phase Card
          // _infoTile(
          //   title: 'Current Phase',
          //   value: phase ?? 'Data missing',
          //   icon: Icons.home,
          //   //isHighlighted: true,
          // ),

           _infoTile(
            title: "Today's Recap",
            value: Text(info).data!,
            icon: Icons.favorite,
          ),

          _infoTile( //do we still need this if it shows in the circle?
            title: 'Day Of $phase', 
            value: dayOfPhase != null ? '$dayOfPhase' : 'Data missing',
            icon: Icons.calendar_today_rounded,
            //isHighlighted: true,
          ),

         

        ],
      ),
    )),);
  }

  Widget _infoTile({
    required String title,
    required String value,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color.fromARGB(13, 9, 206, 52)
            : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromRGBO(54, 18, 58, 1)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF303437),
                    fontSize: 14,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    height: 1.43,
                    ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF303437),
                    fontSize: 14,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w400,
                    height: 1.79,
                    ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160,
        child: HorizontalScrollButton(
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push(context,
            //   MaterialPageRoute(builder: (_) => page),
            // );
          },
        ),
      ),
    );
  }
}


class CyclePainter extends CustomPainter {
  final double currentProgress;
  final List<int> phaseLengths;

  CyclePainter({required this.currentProgress, required this.phaseLengths});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 20; 
    const strokeWidth = 22.0;

    // Colors matching the design
    final colors = [
      const Color(0xFFF6A3A3),
      const Color(0xFFF9D5FF), 
      const Color(0xFFC1E5FF), 
      const Color(0xFFFFE6C4), 
      const Color(0xFFD0D4FF), 
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Calculate the actual total days from the current phase list
    int totalDays = phaseLengths.fold(0, (sum, next) => sum + next);
    if (totalDays <= 0) totalDays = 28; // Fallback to avoid division by zero
    
    // 2. Define the gaps between segments
    double gap = 0.2; // Radians
    double totalGapSpace = gap * phaseLengths.length;
    double availableAngle = (2 * pi) - totalGapSpace; 

   // 3. Start at the top (-90 degrees)
    double currentStartAngle = -pi / 2 + (gap / 2);

    for (int i = 0; i < phaseLengths.length; i++) {
      // Calculate angle relative to available space
      double sweepAngle = (phaseLengths[i] / totalDays) * availableAngle;

      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentStartAngle,
        sweepAngle,
        false,
        paint,
      );

      // Advance the start angle for the next segment
      currentStartAngle += sweepAngle + gap;
    }

    // 4. Draw the White Progress Indicator Dot
    final indicatorPaint = Paint()..color = Colors.white;
    //double currentAngle = -pi / 2 + (2 * pi * currentProgress);

    // Map progress (0.0 to 1.0) to a full circle rotation
    double indicatorAngle = -pi / 2 + (2 * pi * currentProgress);

    Offset dotCenter = Offset(
      center.dx + radius * cos(indicatorAngle),
      center.dy + radius * sin(indicatorAngle),
    );
    
    // Add a small shadow to the dot to make it pop
    canvas.drawShadow(Path()..addOval(Rect.fromCircle(center: dotCenter, radius: 8)), Colors.black, 3, false);
    canvas.drawCircle(dotCenter, 8, indicatorPaint);
  }

  @override
  bool shouldRepaint(CyclePainter oldDelegate) => 
      oldDelegate.currentProgress != currentProgress || oldDelegate.phaseLengths != phaseLengths;
}


class DailyTipsPage extends StatelessWidget {
  const DailyTipsPage({super.key});
  static List<CycleDataProvider> estrogenData = [
    CycleDataProvider() 
  ];

  
  @override
  Widget build(BuildContext context) {
    
    final length = context.read<Calculate>().updateCycleLength;
    // for getting hormone data - add this wherever need graph
    final phasesInOrder = [
      'Menstruation',
      'Follicular',
      'Ovulation',
      'Early Luteal',
      'Late Luteal',
    ];



    // data loaded into page 
    final calc = context.watch<Calculate>();
    // final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;

    final today = DateTime.now();

    final cycleData = context.watch<CycleDataProvider>();
    final selectedField = cycleData.selectedField;

    bool isSelected(String hormoneLabel) {
  return selectedField == hormoneLabel;
}


// final todayX = difference.toDouble(); // day in cycle




    final hormoneGraph = [
      'Effects of Estrogen',
      'Effects of Progesterone',
      'Effects of LH',
      'Effects of FSH',
    ].contains(selectedField);

final energyGraph = ["Energy Levels Info"].contains(selectedField);

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

  final info = (phase != null && dayOfPhase != null)
      ? cycleData.getPhaseInfo(
          phase: phase,
          dayOfPhase: dayOfPhase,
          field: selectedField,
        )
      : 'No data';

    // add this wherever need graph 



final Map<String, double> phaseStartX = {};
final Map<String, double> phaseEndX = {};

List<FlSpot> estrogenSpots = [];
double xEstrogen = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  if (days.isEmpty) continue;

  phaseStartX[phaseName] = xEstrogen;

  for (final day in days) {
    final estrogen = day.getDouble('Level of Estrogen');
    if (estrogen != null) {
      estrogenSpots.add(FlSpot(xEstrogen, estrogen));
      xEstrogen += 1;
    }
  }

  phaseEndX[phaseName] = xEstrogen - 1;
}


List<FlSpot> progesteroneSpots = [];
double xProgesterone = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final progesterone = day.getDouble('Level of Progesterone');
    if (progesterone != null) {
      progesteroneSpots.add(FlSpot(xProgesterone, progesterone));
      xProgesterone += 1;
    }
  }
}

List<FlSpot> fshSpots = [];
double xFsh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final fsh = day.getDouble('Level of FSH');
    if (fsh != null) {
      fshSpots.add(FlSpot(xFsh, fsh));
      xFsh += 1;
    }
  }
}

List<FlSpot> lhSpots = [];
double xLh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final lh = day.getDouble('Level of LH');
    if (lh != null) {
      lhSpots.add(FlSpot(xLh, lh));
      xLh += 1;
    }
  }
}
final maxX = [
  estrogenSpots,
  progesteroneSpots,
  fshSpots,
  lhSpots,
]
    .where((list) => list.isNotEmpty)
    .map((list) => list.last.x)
    .fold<double>(0.0, (prev, x) => x > prev ? x : prev);




List<FlSpot> energySpots = [];
double xEnergy = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final energy = day.getDouble('Energy Levels');
    if (energy != null) {
      energySpots.add(FlSpot(xEnergy, energy));
      xEnergy += 1;
    }
  }
}

final phaseColors = {
  'Menstruation': const Color(0xFFF6A3A3),
  'Follicular': const Color(0xFFF9D5FF),
  'Ovulation': const Color(0xFFC1E5FF), 
  'Early Luteal': const Color(0xFFFFE6C4),
  'Late Luteal': const Color(0xFFD0D4FF),
};
// design change these to match color scheme
const double ovulationHighlightBuffer = 0.5;
final phaseAnnotations = phaseStartX.containsKey(phase)
    ? <VerticalRangeAnnotation>[
        VerticalRangeAnnotation(
          x1: phase == 'Ovulation'
              ? (phaseStartX[phase]! - ovulationHighlightBuffer).clamp(0, maxX)
              : phaseStartX[phase]!,
          x2: phase == 'Ovulation'
              ? (phaseEndX[phase]! + ovulationHighlightBuffer).clamp(0, maxX)
              : phaseEndX[phase]!,
          color: (phaseColors[phase] ?? Colors.grey).withOpacity(0.35),
        )
      ]
    : <VerticalRangeAnnotation>[];



    // design of page 
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Daily Tips'),
      // ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                 clipBehavior: Clip.none,
                children: [

              Container(
                width: 3299,
                height: 89, // size of pink container
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration( // design of pink container
                  color: const Color(0xFFFBE3E4),
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 61.0, left: 24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Day $difference',
                            style: TextStyle(
                              color: Color(0xFF202325),
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'DM Sans',
                            )
                          ),
                          Text(
                            ' $phase',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                            color: Color(0xFF5454CA),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'DM Sans'
                            )
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                          //  'Today, $today.year, $today.month, $today.day',
                            'Today, ${today.day}/${today.month}/${today.year}',
                            style: TextStyle( // edit text of today within pink container
                              color: Color(0xFF404446),
                              fontSize: 14,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w400,
                          ),
                          ),
                        ],
                        )
                    ],
                  ),
                ),
              ),
               Positioned(
              top: 35,   // Adjust these to get the exact "sit" you want
              right: 10,
              child: Image.asset(
                'assets/woman_in_swimsuit.png',
                width: 100, // Adjust size based on your asset
              ),
            ),
                ]
              ),
              SizedBox(height: 30),

              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                ' Health Tips',
                style: TextStyle(
                    color: const Color(0xFF404446),
                    fontSize: 18,
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w700,
                    height: 1.33,
                ),
              )
              ),

              SizedBox(height: 10),

              SizedBox(
              height: 120, // controls button size
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildButton(
                    context,
                    "Phase Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Estrogen",
                    const MenstruationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Progesterone",
                    const FolicularPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of FSH",
                    const OvulationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of LH",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Energy Levels Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "What to eat",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Foods and Recipes",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Concentration",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Health",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Mood",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Types of Vitamins",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Brain",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Ovaries",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Uterus",
                    const EarlyLutealPage(),
                  )
                ],
              ),
            ),

              SizedBox(height: 20),
if (hormoneGraph)...[
              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                
                child: 
                Column(
                  children: [
                    Row(
                      children: const [ // design
        _LegendItem(color:  Color.fromARGB(255, 230, 113, 152), label: 'Estrogen'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurple, label: 'Progesterone'),
        SizedBox(width: 16),
               _LegendItem(color: Color.fromARGB(255, 114, 243, 107), label: 'FSH'),
        SizedBox(width: 16),
        _LegendItem(color: Color.fromARGB(255, 82, 102, 216), label: 'LH'),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),


                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Hormone Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            
                            LineChartBarData(
  spots: estrogenSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 230, 113, 152)
      .withOpacity(isSelected('Effects of Estrogen') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Estrogen') ? 2.5 : 2,
),
                            LineChartBarData(
  spots: progesteroneSpots,
  isCurved: false,
  color: Colors.deepPurple
      .withOpacity(isSelected('Effects of Progesterone') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Progesterone') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: lhSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 111, 174, 237)
      .withOpacity(isSelected('Effects of LH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of LH') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: fshSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 114, 243, 107)
      .withOpacity(isSelected('Effects of FSH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of FSH') ? 2.5 : 2,
),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),],
if (energyGraph)...[
Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                child: 
                Column(
                  children: [
                    Row(
                      children: const [
        _LegendItem(color:  Color.fromARGB(255, 40, 71, 227), label: 'Energy Level'),
        SizedBox(width: 16),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

                          rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Energy Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: false,
                              color: const Color.fromARGB(255, 40, 71, 227),
                              dotData: FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),
],

              SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Information', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: 
                  _infoTile(
                    title: selectedField,
                    value: 
                    // cycleData.getPhaseInfo(
                    //     phase: phase,
                    //     dayOfPhase: dayOfPhase,
                    //     field: selectedField,
                    Text(info).data!,
                      
                    // : 'No data'), // fallback if phase or dayOfPhase is null
                  ),
                  
              
              ),

              SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Upcoming Phases', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 90, // controls button size
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildButtonPhases(
                      context,
                      "Menstruation",
                      const MenstruationPage(),
                    ),
                    _buildButtonPhases(
                      context,
                      "Follicular",
                      const FolicularPage(),
                    ),
                    _buildButtonPhases(
                      context,
                      "Ovulation",
                      const OvulationPage(),
                    ),
                    _buildButtonPhases(
                      context,
                      "Early Luteal",
                      const EarlyLutealPage(),
                    ),
                    _buildButtonPhases(
                      context,
                      "Late Luteal",
                      const LateLutealPage(),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    ),
    );
    }

  //this one doesnt need an icon
  Widget _infoTile({
    required String title,
    required String value,
    //required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Icon(icon, color: const Color.fromARGB(255, 112, 161, 217)),
          // const SizedBox(width: 15),
          Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( // make a new class with a different deign for these
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push();
            //MaterialPageRoute(builder: (_) => page),
          },
        ),
      ),
    );
  }
}

  Widget _buildButtonPhases(BuildContext context, String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 292, // controls how many buttons fit on screen
        child: HorizontalScrollButtonPhases(
          label: label,
          colorBox: label,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            );
          },
        ),
      ),
    );
  }



class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

  class _CalendarPageState extends State<CalendarPage> {
    // Focused & selected days
    DateTime _focusedDay = DateTime.now();
    DateTime? _selectedDay;

    // Predicted period days
    final Set<DateTime> _predictedPeriodDays = {};

    DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    List<DateTime> _predictedPeriodDaysStart = [];

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      // Read your Calculate provider
      final calc = context.read<Calculate>();

      // Compute predicted periods using your function
      _computeFuturePeriods(calc);
    }



    // @override
    // void initState() {
    //   super.initState();

    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     final calc = context.read<Calculate>();
    //     calc.addListener(_onCalcUpdated);
    //     _computeFuturePeriods();
    //     setState(() {});
    //   });
    // }

    // void _onCalcUpdated() {
    //   _computeFuturePeriods();
    //   setState(() {});
    // }

    // @override
    // void dispose() {
    //   context.read<Calculate>().removeListener(_onCalcUpdated);
    //   super.dispose();
    // }

    // ------------------ PERIOD PREDICTION ------------------

    void _computeFuturePeriods(Calculate calc) {
    _predictedPeriodDays.clear();
    _predictedPeriodDaysStart.clear();
    

    if (calc.nextPeriodDate == null) return;

    //DateTime predictedStart = _dateOnly(calc.lastPeriodDate!);
    int cycleLength = calc.cycleLength;
    int periodLength = calc.periodLength;

    //predictedStart = predictedStart.add(Duration(days: cycleLength));

    DateTime currentStart = _dateOnly(calc.lastPeriodDate!);
    for (int j = 0; j < periodLength; j++) {
      _predictedPeriodDays.add(
        _dateOnly(currentStart.add(Duration(days: j))),
      );
    }

    DateTime predictedStart = _dateOnly(calc.lastPeriodDate!);

    for (int i = 0; i < 72; i++) {
      _predictedPeriodDaysStart.add(predictedStart);

      for (int j = 0; j < periodLength; j++) {
        _predictedPeriodDays.add(
          _dateOnly(predictedStart.add(Duration(days: j))),
        );
      }
      predictedStart = predictedStart.add(Duration(days: cycleLength));
    }
  }


    bool _isPredictedPeriod(DateTime day) {
      return _predictedPeriodDays.any((d) => isSameDay(d, day));
    }

    /// within ±5 days of predicted period
    bool isWithin5Days(DateTime day) {
      for (int offset = -5; offset <= 5; offset++) {
        if (_predictedPeriodDays.any(
          (predicted) =>
              isSameDay(predicted, day.add(Duration(days: offset))),
        )) {
          return true;
        }
      }
      return false;
    }


    @override
    Widget build(BuildContext context) {
      final calc = context.watch<Calculate>();

      _computeFuturePeriods(calc);

      final cycleData = context.watch<CycleDataProvider>();

      if (!cycleData.isLoaded) {
        return const Center(child: CircularProgressIndicator());
      }

      // final phase = calc.phase;
      // final dayOfPhase = calc.dayofphase;


      //   final info = (phase != null && dayOfPhase != null)
      //       ? cycleData.getPhaseInfo(
      //           phase: phase,
      //           dayOfPhase: dayOfPhase,
      //           field: "Today's Recap",
      //         )
      //       : 'No data';

      String selectedPhase = '';
      int? selectedDayOfPhase;
      if (_selectedDay != null && calc.nextPeriodDate != null) {
        // compute cycle day relative to last period
        //final lastPeriodDate = calc.nextPeriodDate!.subtract(Duration(days: calc.cycleLength));

        final daysFromLastPeriod =_selectedDay!.difference(calc.lastPeriodDate!).inDays;

        final cycleDay = (daysFromLastPeriod % calc.cycleLength) + 1;

        final result = calc.getPhaseForCycleDay(cycleDay: cycleDay);

        selectedPhase = calc.phaseNameFromIndex(result["phase"]!);

        selectedDayOfPhase = result["day"];

        //final cycleDay = (_selectedDay!.difference(lastPeriodDate).inDays % calc.cycleLength) + 1;

        // determine phase for that day
        // calc.determinePhase(
        //   cycleDay: cycleDay,
        //   cycleLength: calc.cycleLength,
        //   periodLength: calc.periodLength,
        // );

        // selectedPhase = calc.phase ?? '';
      }

      //what is shown in recap box
      String info;

      if (_selectedDay != null && selectedDayOfPhase != null) {
        // recap for selected calendar day
        info = cycleData.getPhaseInfo(
          phase: selectedPhase,
          dayOfPhase: selectedDayOfPhase!,
          field: "Today's Recap",
        );
      } else if (calc.phase != null && calc.dayofphase != null) {
        // recap for today
        info = cycleData.getPhaseInfo(
          phase: calc.phase!,
          dayOfPhase: calc.dayofphase!,
          field: "Today's Recap",
        );
      } else {
        info = "Loading...";
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Calendar',
            style: TextStyle(
              color: Color(0xFF202325),
              fontSize: 24,
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w700,
              height: 1.33,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365 * 5)),
                focusedDay: _focusedDay,
          
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
          
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    //predicted period
                    if (_isPredictedPeriod(day)) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5757B),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                      );
                    }
          
                    final calc = context.read<Calculate>();
          
                    // for (final periodStart in _predictedPeriodDaysStart) {
                    //   DateTime ovulation = periodStart.add(Duration(days: calc.cycleLength - 14-1));
                    //   if (isSameDay(day, ovulation)) {
                    //     return _buildCircle(day, color: Color(0xFFC1E5FF), textColor: Color(0xFF72777A));
                    //   }
                    // }
          
                    for (final periodStart in _predictedPeriodDaysStart) {
                      DateTime ovulation = periodStart.add(Duration(days: calc.cycleLength - 14-1));
                      if (isSameDay(day, ovulation)) {
                        return Container(
                          margin: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC1E5FF),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Color(0xFF72777A),
                              fontSize: 16,
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w400,
                              height: 1.40,
                            ),
                          ),
                        );
                      }
                    }
          
                    // uncertainty
                    if (isWithin5Days(day)) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBE3E4),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Color(0xFF72777A),
                            fontSize: 16,
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w400,
                            height: 1.40,
                          ),
                        ),
                      );
                    }
          
                    return null;
                  },
                ),
          
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Color(0xFF303437),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFF5454CA),
                    shape: BoxShape.circle,
                  ),
                ),
          
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
          
              const SizedBox(height: 30),
          
              if (_selectedDay != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '$selectedPhase',
                    style: TextStyle(
                      color: const Color(0xFF303437),
                      fontSize: 30,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w700,
                      height: 1.33,
                      ),
                  ),
                ),
          
              const SizedBox(height: 10),
          
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: _infoTile(
                title: "Today's Recap",
                value: info,
                icon: Icons.favorite,
                          ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _infoTile({
    required String title,
    required String value,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color.fromRGBO(54, 18, 58, 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromRGBO(54, 18, 58, 1)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF303437),
                    fontSize: 14,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    height: 1.43,
                    ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF303437),
                    fontSize: 14,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w400,
                    height: 1.79,
                    ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class MenstruationPage extends StatelessWidget{
  const MenstruationPage({super.key});
  final DateTime? nextPeriodDate = null;

Future<String> _loadMenstruationInfo(String selectedField) async {
  final jsonString = await rootBundle.loadString('assets/All_Phases.json');
  final List<dynamic> decoded = json.decode(jsonString);

  final List<Map<String, dynamic>> allData =
      decoded.cast<Map<String, dynamic>>();

  final Map<String, dynamic> menstruationEntry = allData.firstWhere(
    (entry) => entry['Phase'] == 'Menstrual',
    orElse: () => {},
  );
  final data = menstruationEntry[selectedField]?.toString();

  return data ?? 'No data';
}

  
  @override
  Widget build(BuildContext context) {
final length = context.read<Calculate>().updateCycleLength;
    // for getting hormone data - add this wherever need graph
    final phasesInOrder = [
      'Menstruation',
      'Follicular',
      'Ovulation',
      'Early Luteal',
      'Late Luteal',
    ];

const String highlightedPhase = 'Menstruation';



    // data loaded into page 
    final calc = context.watch<Calculate>();
    // final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;

    final today = DateTime.now();

    final cycleData = context.watch<CycleDataProvider>();
    final selectedField = cycleData.selectedField;

    bool isSelected(String hormoneLabel) {
  return selectedField == hormoneLabel;
}

    final hormoneGraph = [
      'Effects of Estrogen',
      'Effects of Progesterone',
      'Effects of LH',
      'Effects of FSH',
    ].contains(selectedField);

final energyGraph = ["Energy Levels Info"].contains(selectedField);

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

  final info = (phase != null && dayOfPhase != null)
      ? cycleData.getPhaseInfo(
          phase: phase,
          dayOfPhase: dayOfPhase,
          field: selectedField,
        )
      : 'No data';

    // add this wherever need graph 



final Map<String, double> phaseStartX = {};
final Map<String, double> phaseEndX = {};

List<FlSpot> estrogenSpots = [];
double xEstrogen = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  if (days.isEmpty) continue;

  phaseStartX[phaseName] = xEstrogen;

  for (final day in days) {
    final estrogen = day.getDouble('Level of Estrogen');
    if (estrogen != null) {
      estrogenSpots.add(FlSpot(xEstrogen, estrogen));
      xEstrogen += 1;
    }
  }

  phaseEndX[phaseName] = xEstrogen - 1;
}


List<FlSpot> progesteroneSpots = [];
double xProgesterone = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final progesterone = day.getDouble('Level of Progesterone');
    if (progesterone != null) {
      progesteroneSpots.add(FlSpot(xProgesterone, progesterone));
      xProgesterone += 1;
    }
  }
}

List<FlSpot> fshSpots = [];
double xFsh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final fsh = day.getDouble('Level of FSH');
    if (fsh != null) {
      fshSpots.add(FlSpot(xFsh, fsh));
      xFsh += 1;
    }
  }
}

List<FlSpot> lhSpots = [];
double xLh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final lh = day.getDouble('Level of LH');
    if (lh != null) {
      lhSpots.add(FlSpot(xLh, lh));
      xLh += 1;
    }
  }
}
final maxX = [
  estrogenSpots,
  progesteroneSpots,
  fshSpots,
  lhSpots,
]
    .where((list) => list.isNotEmpty)
    .map((list) => list.last.x)
    .fold<double>(0.0, (prev, x) => x > prev ? x : prev);




List<FlSpot> energySpots = [];
double xEnergy = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final energy = day.getDouble('Energy Levels');
    if (energy != null) {
      energySpots.add(FlSpot(xEnergy, energy));
      xEnergy += 1;
    }
  }
}

final phaseColors = {
  'Menstruation': const Color.fromARGB(64, 217, 28, 56),
  'Follicular': const Color.fromRGBO(173, 216, 230, 0.25),
  'Ovulation': const Color.fromRGBO(144, 238, 144, 0.25), 
  'Early Luteal': const Color.fromRGBO(221, 160, 221, 0.25),
  'Late Luteal': const Color.fromRGBO(255, 228, 181, 0.25),
};
// design change these to match color scheme

final List<VerticalRangeAnnotation> phaseAnnotations =
    (phaseStartX.containsKey(highlightedPhase) &&
     phaseEndX.containsKey(highlightedPhase))
        ? [
            VerticalRangeAnnotation(
              x1: phaseStartX[highlightedPhase]!,
              x2: phaseEndX[highlightedPhase]!,
              color: (phaseColors[highlightedPhase] ?? const Color.fromARGB(137, 252, 62, 62))
                  .withOpacity(0.35),
            ),
          ]
        : [];
      
// final todayX = difference!.toDouble(); // day in cycle

// extraLinesData: ExtraLinesData(
//   verticalLines: [
//     VerticalLine(
//       x: todayX,
//       color: Colors.black54,
//       strokeWidth: 2,
//       dashArray: [5, 5],
//     ),
//   ],
// );


    return Scaffold(
      body: SafeArea(
      child:
      SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: 
      // Container(
      //   width: double.infinity,
      //   padding: const EdgeInsets.all(20.0),
        // child: 
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'MENSTRUATION',
              style: TextStyle(
                color: const Color(0xFF5454CA),
                fontSize: 36,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                height: 0.67,
                letterSpacing: 1.44,
                ),
            ),
            SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child:
              Text(
                'Information',
                style: TextStyle(
                  color:  Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                ),
              )
            ),

            SizedBox(height: 16),

            SizedBox(
              height: 120, // controls button size
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildButton(
                    context,
                    "Phase Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Estrogen",
                    const MenstruationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Progesterone",
                    const FolicularPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of FSH",
                    const OvulationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of LH",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Energy Levels Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "What to eat",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Foods and Recipes",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Concentration",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Health",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Mood",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Types of Vitamins",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Brain",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Ovaries",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Uterus",
                    const EarlyLutealPage(),
                  )
                ],
              ),
            ),
          SizedBox(height:20),
        if (hormoneGraph)...[
              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                
                child: 
                Column(
                  children: [
                    Row(
                      children: const [ // design
        _LegendItem(color:  Color.fromARGB(255, 230, 113, 152), label: 'Estrogen'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurple, label: 'Progesterone'),
        SizedBox(width: 16),
               _LegendItem(color: Color.fromARGB(255, 114, 243, 107), label: 'FSH'),
        SizedBox(width: 16),
        _LegendItem(color: Color.fromARGB(255, 82, 102, 216), label: 'LH'),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Hormone Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            
                            LineChartBarData(
  spots: estrogenSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 230, 113, 152)
      .withOpacity(isSelected('Effects of Estrogen') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Estrogen') ? 2.5 : 2,
),
                            LineChartBarData(
  spots: progesteroneSpots,
  isCurved: false,
  color: Colors.deepPurple
      .withOpacity(isSelected('Effects of Progesterone') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Progesterone') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: lhSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 111, 174, 237)
      .withOpacity(isSelected('Effects of LH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of LH') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: fshSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 114, 243, 107)
      .withOpacity(isSelected('Effects of FSH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of FSH') ? 2.5 : 2,
),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),],
if (energyGraph)...[
Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                child: 
                Column(
                  children: [
                    Row(
                      children: const [
        _LegendItem(color:  Color.fromARGB(255, 40, 71, 227), label: 'Energy Level'),
        SizedBox(width: 16),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

                          rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Energy Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: false,
                              color: const Color.fromARGB(255, 40, 71, 227),
                              dotData: FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),
],
 SizedBox(height:20),

          Align(
            alignment: Alignment.centerLeft,
                child:
                Text(
                'Explanation', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

             Padding(
  padding: const EdgeInsets.only(top: 20.0),
  child: FutureBuilder<String>(
      future: _loadMenstruationInfo(selectedField),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _infoTile(title: selectedField, value: 'Error loading data');
        }

        return _infoTile(
          title: selectedField,
          value: snapshot.data ?? 'No data',
        );
    
      },
      )
    
  ),
]
)
)
      ));
}

//this one doesnt need an icon
  Widget _infoTile({
    required String title,
    required String value,
    //required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Icon(icon, color: const Color.fromARGB(255, 112, 161, 217)),
          // const SizedBox(width: 15),
          Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( // make a new class with a different deign for these
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push();
            //MaterialPageRoute(builder: (_) => page),
            
          },
        ),
      ),
    );
  }
}

class FolicularPage extends StatelessWidget{
  const FolicularPage({super.key});
Future<String> _loadFollicularInfo(String selectedField) async {
  final jsonString = await rootBundle.loadString('assets/All_Phases.json');
  final List<dynamic> decoded = json.decode(jsonString);

  final List<Map<String, dynamic>> allData =
      decoded.cast<Map<String, dynamic>>();

  final Map<String, dynamic> menstruationEntry = allData.firstWhere(
    (entry) => entry['Phase'] == 'Follicular',
    orElse: () => {},
  );
  final data = menstruationEntry[selectedField]?.toString();

  return data ?? 'No data';
}

  
  @override
  Widget build(BuildContext context) {
   final length = context.read<Calculate>().updateCycleLength;
    // for getting hormone data - add this wherever need graph
    final phasesInOrder = [
      'Menstruation',
      'Follicular',
      'Ovulation',
      'Early Luteal',
      'Late Luteal',
    ];


final highlightedPhase = "Follicular";

    // data loaded into page 
    final calc = context.watch<Calculate>();
    // final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;

    final today = DateTime.now();

    final cycleData = context.watch<CycleDataProvider>();
    final selectedField = cycleData.selectedField;

  bool isSelected(String hormoneLabel) {
  return selectedField == hormoneLabel;
}

    final hormoneGraph = [
      'Effects of Estrogen',
      'Effects of Progesterone',
      'Effects of LH',
      'Effects of FSH',
    ].contains(selectedField);

final energyGraph = ["Energy Levels Info"].contains(selectedField);

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

  final info = (phase != null && dayOfPhase != null)
      ? cycleData.getPhaseInfo(
          phase: phase,
          dayOfPhase: dayOfPhase,
          field: selectedField,
        )
      : 'No data';

    // add this wherever need graph 



final Map<String, double> phaseStartX = {};
final Map<String, double> phaseEndX = {};

List<FlSpot> estrogenSpots = [];
double xEstrogen = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  if (days.isEmpty) continue;

  phaseStartX[phaseName] = xEstrogen;

  for (final day in days) {
    final estrogen = day.getDouble('Level of Estrogen');
    if (estrogen != null) {
      estrogenSpots.add(FlSpot(xEstrogen, estrogen));
      xEstrogen += 1;
    }
  }

  phaseEndX[phaseName] = xEstrogen - 1;
}


List<FlSpot> progesteroneSpots = [];
double xProgesterone = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final progesterone = day.getDouble('Level of Progesterone');
    if (progesterone != null) {
      progesteroneSpots.add(FlSpot(xProgesterone, progesterone));
      xProgesterone += 1;
    }
  }
}

List<FlSpot> fshSpots = [];
double xFsh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final fsh = day.getDouble('Level of FSH');
    if (fsh != null) {
      fshSpots.add(FlSpot(xFsh, fsh));
      xFsh += 1;
    }
  }
}

List<FlSpot> lhSpots = [];
double xLh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final lh = day.getDouble('Level of LH');
    if (lh != null) {
      lhSpots.add(FlSpot(xLh, lh));
      xLh += 1;
    }
  }
}
final maxX = [
  estrogenSpots,
  progesteroneSpots,
  fshSpots,
  lhSpots,
]
    .where((list) => list.isNotEmpty)
    .map((list) => list.last.x)
    .fold<double>(0.0, (prev, x) => x > prev ? x : prev);




List<FlSpot> energySpots = [];
double xEnergy = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final energy = day.getDouble('Energy Levels');
    if (energy != null) {
      energySpots.add(FlSpot(xEnergy, energy));
      xEnergy += 1;
    }
  }
}

final phaseColors = {
  'Menstruation': const Color.fromARGB(64, 217, 28, 56),
  'Follicular': const Color.fromRGBO(173, 216, 230, 0.25),
  'Ovulation': const Color.fromRGBO(144, 238, 144, 0.25), 
  'Early Luteal': const Color.fromRGBO(221, 160, 221, 0.25),
  'Late Luteal': const Color.fromRGBO(255, 228, 181, 0.25),
};
// design change these to match color scheme

final List<VerticalRangeAnnotation> phaseAnnotations =
    (phaseStartX.containsKey(highlightedPhase) &&
     phaseEndX.containsKey(highlightedPhase))
        ? [
            VerticalRangeAnnotation(
              x1: phaseStartX[highlightedPhase]!,
              x2: phaseEndX[highlightedPhase]!,
              color: (phaseColors[highlightedPhase] ?? const Color.fromARGB(141, 65, 226, 244))
                  .withOpacity(0.35),
            ),
          ]
        : [];


    return Scaffold(
      body: SafeArea(
      child:
      SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: 
      // Container(
      //   width: double.infinity,
      //   padding: const EdgeInsets.all(20.0),
        // child: 
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'FOLLICULAR',
              style: TextStyle(
                color: const Color(0xFF5454CA),
                fontSize: 36,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                height: 0.67,
                letterSpacing: 1.44,
                ),
            ),
            SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child:
              Text(
                'Information',
                style: TextStyle(
                  color:  Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                ),
              )
            ),

            SizedBox(height: 16),

            SizedBox(
              height: 120, // controls button size
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildButton(
                    context,
                    "Phase Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Estrogen",
                    const MenstruationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Progesterone",
                    const FolicularPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of FSH",
                    const OvulationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of LH",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Energy Levels Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "What to eat",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Foods and Recipes",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Concentration",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Health",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Mood",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Types of Vitamins",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Brain",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Ovaries",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Uterus",
                    const EarlyLutealPage(),
                  )
                ],
              ),
            ),
          SizedBox(height:20),
        if (hormoneGraph)...[
              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                
                child: 
                Column(
                  children: [
                    Row(
                      children: const [ // design
        _LegendItem(color:  Color.fromARGB(255, 230, 113, 152), label: 'Estrogen'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurple, label: 'Progesterone'),
        SizedBox(width: 16),
               _LegendItem(color: Color.fromARGB(255, 114, 243, 107), label: 'FSH'),
        SizedBox(width: 16),
        _LegendItem(color: Color.fromARGB(255, 82, 102, 216), label: 'LH'),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Hormone Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            
                            LineChartBarData(
  spots: estrogenSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 230, 113, 152)
      .withOpacity(isSelected('Effects of Estrogen') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Estrogen') ? 2.5 : 2,
),
                            LineChartBarData(
  spots: progesteroneSpots,
  isCurved: false,
  color: Colors.deepPurple
      .withOpacity(isSelected('Effects of Progesterone') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Progesterone') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: lhSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 111, 174, 237)
      .withOpacity(isSelected('Effects of LH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of LH') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: fshSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 114, 243, 107)
      .withOpacity(isSelected('Effects of FSH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of FSH') ? 2.5 : 2,
),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),],
if (energyGraph)...[
Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                child: 
                Column(
                  children: [
                    Row(
                      children: const [
        _LegendItem(color:  Color.fromARGB(255, 40, 71, 227), label: 'Energy Level'),
        SizedBox(width: 16),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

                          rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Energy Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: false,
                              color: const Color.fromARGB(255, 40, 71, 227),
                              dotData: FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),
],
 SizedBox(height:20),

          Align(
            alignment: Alignment.centerLeft,
                child:
                Text(
                'Explanation', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

             Padding(
  padding: const EdgeInsets.only(top: 20.0),
  child: FutureBuilder<String>(
      future: _loadFollicularInfo(selectedField),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _infoTile(title: selectedField, value: 'Error loading data');
        }

        return _infoTile(
          title: selectedField,
          value: snapshot.data ?? 'No data',
        );
    
      },
      )
    
  ),
]
)
)
      ));
}

//this one doesnt need an icon
  Widget _infoTile({
    required String title,
    required String value,
    //required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Icon(icon, color: const Color.fromARGB(255, 112, 161, 217)),
          // const SizedBox(width: 15),
          Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( // make a new class with a different deign for these
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push();
            //MaterialPageRoute(builder: (_) => page),
            
          },
        ),
      ),
    );
  }
}


class OvulationPage extends StatelessWidget{
  const OvulationPage({super.key});
Future<String> _loadOvulationInfo(String selectedField) async {
  final jsonString = await rootBundle.loadString('assets/All_Phases.json');
  final List<dynamic> decoded = json.decode(jsonString);

  final List<Map<String, dynamic>> allData =
      decoded.cast<Map<String, dynamic>>();

  final Map<String, dynamic> ovulationEntry = allData.firstWhere(
    (entry) => entry['Phase'] == 'Ovulation',
    orElse: () => {},
  );
  final data = ovulationEntry[selectedField]?.toString();

  return data ?? 'No data';
}

  
  @override
  Widget build(BuildContext context) {
        final length = context.read<Calculate>().updateCycleLength;
    // for getting hormone data - add this wherever need graph
    final phasesInOrder = [
      'Menstruation',
      'Follicular',
      'Ovulation',
      'Early Luteal',
      'Late Luteal',
    ];
final highlightedPhase = "Ovulation";


    // data loaded into page 
    final calc = context.watch<Calculate>();
    // final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;

    final today = DateTime.now();

    final cycleData = context.watch<CycleDataProvider>();
    final selectedField = cycleData.selectedField;

    bool isSelected(String hormoneLabel) {
  return selectedField == hormoneLabel;
}

    final hormoneGraph = [
      'Effects of Estrogen',
      'Effects of Progesterone',
      'Effects of LH',
      'Effects of FSH',
    ].contains(selectedField);

final energyGraph = ["Energy Levels Info"].contains(selectedField);

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

  final info = (phase != null && dayOfPhase != null)
      ? cycleData.getPhaseInfo(
          phase: phase,
          dayOfPhase: dayOfPhase,
          field: selectedField,
        )
      : 'No data';

    // add this wherever need graph 



final Map<String, double> phaseStartX = {};
final Map<String, double> phaseEndX = {};

List<FlSpot> estrogenSpots = [];
double xEstrogen = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  if (days.isEmpty) continue;

  phaseStartX[phaseName] = xEstrogen;

  for (final day in days) {
    final estrogen = day.getDouble('Level of Estrogen');
    if (estrogen != null) {
      estrogenSpots.add(FlSpot(xEstrogen, estrogen));
      xEstrogen += 1;
    }
  }

  phaseEndX[phaseName] = xEstrogen - 1;
}


List<FlSpot> progesteroneSpots = [];
double xProgesterone = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final progesterone = day.getDouble('Level of Progesterone');
    if (progesterone != null) {
      progesteroneSpots.add(FlSpot(xProgesterone, progesterone));
      xProgesterone += 1;
    }
  }
}

List<FlSpot> fshSpots = [];
double xFsh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final fsh = day.getDouble('Level of FSH');
    if (fsh != null) {
      fshSpots.add(FlSpot(xFsh, fsh));
      xFsh += 1;
    }
  }
}

List<FlSpot> lhSpots = [];
double xLh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final lh = day.getDouble('Level of LH');
    if (lh != null) {
      lhSpots.add(FlSpot(xLh, lh));
      xLh += 1;
    }
  }
}
final maxX = [
  estrogenSpots,
  progesteroneSpots,
  fshSpots,
  lhSpots,
]
    .where((list) => list.isNotEmpty)
    .map((list) => list.last.x)
    .fold<double>(0.0, (prev, x) => x > prev ? x : prev);




List<FlSpot> energySpots = [];
double xEnergy = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final energy = day.getDouble('Energy Levels');
    if (energy != null) {
      energySpots.add(FlSpot(xEnergy, energy));
      xEnergy += 1;
    }
  }
}

final phaseColors = {
  'Menstruation': const Color.fromARGB(64, 217, 28, 56),
  'Follicular': const Color.fromRGBO(173, 216, 230, 0.25),
  'Ovulation': const Color.fromRGBO(144, 238, 144, 0.25), 
  'Early Luteal': const Color.fromRGBO(221, 160, 221, 0.25),
  'Late Luteal': const Color.fromRGBO(255, 228, 181, 0.25),
};
// design change these to match color scheme

final List<VerticalRangeAnnotation> phaseAnnotations =
    (phaseStartX.containsKey(highlightedPhase) &&
     phaseEndX.containsKey(highlightedPhase))
        ? [
            VerticalRangeAnnotation(
              x1: (phaseStartX[highlightedPhase]! - 0.5).clamp(0,maxX) ,
              x2: (phaseEndX[highlightedPhase]! +0.5).clamp(0,maxX),
              color: (phaseColors[highlightedPhase] ?? const Color.fromARGB(174, 98, 250, 255))
                  .withOpacity(0.35),
            ),
          ]
        : [];



    return Scaffold(
      body: SafeArea(
      child:
      SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: 
      // Container(
      //   width: double.infinity,
      //   padding: const EdgeInsets.all(20.0),
        // child: 
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'OVULATION',
              style: TextStyle(
                color: const Color(0xFF5454CA),
                fontSize: 36,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                height: 0.67,
                letterSpacing: 1.44,
                ),
            ),
            SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child:
              Text(
                'Information',
                style: TextStyle(
                  color:  Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                ),
              )
            ),

            SizedBox(height: 16),

            SizedBox(
              height: 120, // controls button size
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildButton(
                    context,
                    "Phase Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Estrogen",
                    const MenstruationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Progesterone",
                    const FolicularPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of FSH",
                    const OvulationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of LH",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Energy Levels Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "What to eat",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Foods and Recipes",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Concentration",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Health",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Mood",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Types of Vitamins",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Brain",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Ovaries",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Uterus",
                    const EarlyLutealPage(),
                  )
                ],
              ),
            ),
          SizedBox(height:20),
  if (hormoneGraph)...[
              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                
                child: 
                Column(
                  children: [
                    Row(
                      children: const [ // design
        _LegendItem(color:  Color.fromARGB(255, 230, 113, 152), label: 'Estrogen'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurple, label: 'Progesterone'),
        SizedBox(width: 16),
               _LegendItem(color: Color.fromARGB(255, 114, 243, 107), label: 'FSH'),
        SizedBox(width: 16),
        _LegendItem(color: Color.fromARGB(255, 82, 102, 216), label: 'LH'),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Hormone Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            
                            LineChartBarData(
  spots: estrogenSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 230, 113, 152)
      .withOpacity(isSelected('Effects of Estrogen') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Estrogen') ? 2.5 : 2,
),
                            LineChartBarData(
  spots: progesteroneSpots,
  isCurved: false,
  color: Colors.deepPurple
      .withOpacity(isSelected('Effects of Progesterone') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Progesterone') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: lhSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 111, 174, 237)
      .withOpacity(isSelected('Effects of LH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of LH') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: fshSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 114, 243, 107)
      .withOpacity(isSelected('Effects of FSH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of FSH') ? 2.5 : 2,
),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),],
if (energyGraph)...[
Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                child: 
                Column(
                  children: [
                    Row(
                      children: const [
        _LegendItem(color:  Color.fromARGB(255, 40, 71, 227), label: 'Energy Level'),
        SizedBox(width: 16),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

                          rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Energy Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: false,
                              color: const Color.fromARGB(255, 40, 71, 227),
                              dotData: FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),
],
 SizedBox(height:10),

          Align(
            alignment: Alignment.centerLeft,
                child:
                Text(
                'Explanation', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

             Padding(
  padding: const EdgeInsets.only(top: 20.0),
  child: FutureBuilder<String>(
      future: _loadOvulationInfo(selectedField),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _infoTile(value: 'Error loading data');
        }

        return _infoTile(
          value: snapshot.data ?? 'No data',
        );
    
      },
      )
  
  ),
]
)
)
      ));
}

//this one doesnt need an icon
  Widget _infoTile({
    //required String title,
    required String value,
    //required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        children: [
          //Icon(icon, color: const Color.fromARGB(255, 112, 161, 217)),
          const SizedBox(width: 15),
          Expanded(
            child: 
            Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          ),
        ],
      ),
    );
  }


  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( 
          isSelected: selectedField == label,// make a new class with a different deign for these
          label: label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push();
            //MaterialPageRoute(builder: (_) => page),
            
          },
        ),
      ),
    );
  }
}

  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( // make a new class with a different deign for these
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push();
            //MaterialPageRoute(builder: (_) => page),
            
          },
        ),
      ),
    );
  }


class EarlyLutealPage extends StatelessWidget{
  const EarlyLutealPage({super.key});
Future<String> _loadEarlyLutealInfo(String selectedField) async {
  final jsonString = await rootBundle.loadString('assets/All_Phases.json');
  final List<dynamic> decoded = json.decode(jsonString);

  final List<Map<String, dynamic>> allData =
      decoded.cast<Map<String, dynamic>>();

  final Map<String, dynamic> earlyLutealEntry = allData.firstWhere(
    (entry) => entry['Phase'] == 'Early Luteal',
    orElse: () => {},
  );
  final data = earlyLutealEntry[selectedField]?.toString();

  return data ?? 'No data';
}

  
  @override
  Widget build(BuildContext context) {
    final length = context.read<Calculate>().updateCycleLength;
    // for getting hormone data - add this wherever need graph
    final phasesInOrder = [
      'Menstruation',
      'Follicular',
      'Ovulation',
      'Early Luteal',
      'Late Luteal',
    ];



    // data loaded into page 
    final calc = context.watch<Calculate>();
    // final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;

    final today = DateTime.now();

    final cycleData = context.watch<CycleDataProvider>();
    final selectedField = cycleData.selectedField;

    bool isSelected(String hormoneLabel) {
  return selectedField == hormoneLabel;
}

    final hormoneGraph = [
      'Effects of Estrogen',
      'Effects of Progesterone',
      'Effects of LH',
      'Effects of FSH',
    ].contains(selectedField);

final energyGraph = ["Energy Levels Info"].contains(selectedField);

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

  final info = (phase != null && dayOfPhase != null)
      ? cycleData.getPhaseInfo(
          phase: phase,
          dayOfPhase: dayOfPhase,
          field: selectedField,
        )
      : 'No data';

    // add this wherever need graph 



final Map<String, double> phaseStartX = {};
final Map<String, double> phaseEndX = {};

List<FlSpot> estrogenSpots = [];
double xEstrogen = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  if (days.isEmpty) continue;

  phaseStartX[phaseName] = xEstrogen;

  for (final day in days) {
    final estrogen = day.getDouble('Level of Estrogen');
    if (estrogen != null) {
      estrogenSpots.add(FlSpot(xEstrogen, estrogen));
      xEstrogen += 1;
    }
  }

  phaseEndX[phaseName] = xEstrogen - 1;
}


List<FlSpot> progesteroneSpots = [];
double xProgesterone = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final progesterone = day.getDouble('Level of Progesterone');
    if (progesterone != null) {
      progesteroneSpots.add(FlSpot(xProgesterone, progesterone));
      xProgesterone += 1;
    }
  }
}

List<FlSpot> fshSpots = [];
double xFsh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final fsh = day.getDouble('Level of FSH');
    if (fsh != null) {
      fshSpots.add(FlSpot(xFsh, fsh));
      xFsh += 1;
    }
  }
}

List<FlSpot> lhSpots = [];
double xLh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final lh = day.getDouble('Level of LH');
    if (lh != null) {
      lhSpots.add(FlSpot(xLh, lh));
      xLh += 1;
    }
  }
}
final maxX = [
  estrogenSpots,
  progesteroneSpots,
  fshSpots,
  lhSpots,
]
    .where((list) => list.isNotEmpty)
    .map((list) => list.last.x)
    .fold<double>(0.0, (prev, x) => x > prev ? x : prev);




List<FlSpot> energySpots = [];
double xEnergy = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final energy = day.getDouble('Energy Levels');
    if (energy != null) {
      energySpots.add(FlSpot(xEnergy, energy));
      xEnergy += 1;
    }
  }
}

final phaseColors = {
  'Menstruation': const Color.fromARGB(64, 217, 28, 56),
  'Follicular': const Color.fromRGBO(173, 216, 230, 0.25),
  'Ovulation': const Color.fromRGBO(144, 238, 144, 0.25), 
  'Early Luteal': const Color.fromRGBO(221, 160, 221, 0.25),
  'Late Luteal': const Color.fromRGBO(255, 228, 181, 0.25),
};
// design change these to match color scheme

final highlightedPhase = "Early Luteal";
final List<VerticalRangeAnnotation> phaseAnnotations =
    (phaseStartX.containsKey(highlightedPhase) &&
     phaseEndX.containsKey(highlightedPhase))
        ? [
            VerticalRangeAnnotation(
              x1: phaseStartX[highlightedPhase]!,
              x2: phaseEndX[highlightedPhase]!,
              color: (phaseColors[highlightedPhase] ?? const Color.fromARGB(155, 69, 216, 99))
                  .withOpacity(0.35),
            ),
          ]
        : [];


    return Scaffold(
      body: SafeArea(
      child:
      SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: 
      // Container(
      //   width: double.infinity,
      //   padding: const EdgeInsets.all(20.0),
        // child: 
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'EARLY LUTEAL',
              style: TextStyle(
                color: const Color(0xFF5454CA),
                fontSize: 36,
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w700,
                height: 0.67,
                letterSpacing: 1.44,
                ),
            ),
            SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child:
              Text(
                'Information',
                style: TextStyle(
                  color:  Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                ),
              )
            ),

            SizedBox(height: 16),

            SizedBox(
              height: 120, // controls button size
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildButton(
                    context,
                    "Phase Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Estrogen",
                    const MenstruationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Progesterone",
                    const FolicularPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of FSH",
                    const OvulationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of LH",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Energy Levels Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "What to eat",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Foods and Recipes",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Concentration",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Health",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Mood",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Types of Vitamins",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Brain",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Ovaries",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Uterus",
                    const EarlyLutealPage(),
                  )
                ],
                ),
            ),
          SizedBox(height:20),
if (hormoneGraph)...[
              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                
                child: 
                Column(
                  children: [
                    Row(
                      children: const [ // design
        _LegendItem(color:  Color.fromARGB(255, 230, 113, 152), label: 'Estrogen'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurple, label: 'Progesterone'),
        SizedBox(width: 16),
               _LegendItem(color: Color.fromARGB(255, 114, 243, 107), label: 'FSH'),
        SizedBox(width: 16),
        _LegendItem(color: Color.fromARGB(255, 82, 102, 216), label: 'LH'),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Hormone Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            
                            LineChartBarData(
  spots: estrogenSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 230, 113, 152)
      .withOpacity(isSelected('Effects of Estrogen') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Estrogen') ? 2.5 : 2,
),
                            LineChartBarData(
  spots: progesteroneSpots,
  isCurved: false,
  color: Colors.deepPurple
      .withOpacity(isSelected('Effects of Progesterone') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Progesterone') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: lhSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 111, 174, 237)
      .withOpacity(isSelected('Effects of LH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of LH') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: fshSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 114, 243, 107)
      .withOpacity(isSelected('Effects of FSH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of FSH') ? 2.5 : 2,
),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),],
if (energyGraph)...[
Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                child: 
                Column(
                  children: [
                    Row(
                      children: const [
        _LegendItem(color:  Color.fromARGB(255, 40, 71, 227), label: 'Energy Level'),
        SizedBox(width: 16),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

                          rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Energy Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: false,
                              color: const Color.fromARGB(255, 40, 71, 227),
                              dotData: FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),
],
 SizedBox(height:10),

          Align(
            alignment: Alignment.centerLeft,
                child:
                Text(
                'Explanation', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

             Padding(
  padding: const EdgeInsets.only(top: 20.0),
  child: FutureBuilder<String>(
      future: _loadEarlyLutealInfo(selectedField),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _infoTile(
            title: selectedField,
            value: 'Error loading data');
        }

        return _infoTile(
          title: selectedField,
          value: snapshot.data ?? 'No data',
        );
    
      },
      )
    
  ),
]
)
)
      ));
}

//this one doesnt need an icon
      Widget _infoTile({
    required String title,
    required String value,
    //required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Icon(icon, color: const Color.fromARGB(255, 112, 161, 217)),
          // const SizedBox(width: 15),
          Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( // make a new class with a different deign for these
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            //Navigator.push();
            //MaterialPageRoute(builder: (_) => page),

          },
        ),
      ),
    );
  }
}


class LateLutealPage extends StatelessWidget{
  const LateLutealPage({super.key});

  Future<String> _loadLateLutealInfo(String selectedField) async {
  final jsonString = await rootBundle.loadString('assets/All_Phases.json');
  final List<dynamic> decoded = json.decode(jsonString);

  final List<Map<String, dynamic>> allData =
      decoded.cast<Map<String, dynamic>>();

  final Map<String, dynamic> lateLutealEntry = allData.firstWhere(
    (entry) => entry['Phase'] == 'Late Luteal',
    orElse: () => {},
  );
  final data = lateLutealEntry[selectedField]?.toString();

  return data ?? 'No data';
}

  final bool selected = false;
  
  @override
  Widget build(BuildContext context) {
final length = context.read<Calculate>().updateCycleLength;
    // for getting hormone data - add this wherever need graph
    final phasesInOrder = [
      'Menstruation',
      'Follicular',
      'Ovulation',
      'Early Luteal',
      'Late Luteal',
    ];



    // data loaded into page 
    final calc = context.watch<Calculate>();
    // final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayOfPhase = calc.dayofphase;

    final today = DateTime.now();

    final cycleData = context.watch<CycleDataProvider>();
    final selectedField = cycleData.selectedField;

    bool isSelected(String hormoneLabel) {
  return selectedField == hormoneLabel;
}

    final hormoneGraph = [
      'Effects of Estrogen',
      'Effects of Progesterone',
      'Effects of LH',
      'Effects of FSH',
    ].contains(selectedField);

final energyGraph = ["Energy Levels Info"].contains(selectedField);

    if (!cycleData.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

  final info = (phase != null && dayOfPhase != null)
      ? cycleData.getPhaseInfo(
          phase: phase,
          dayOfPhase: dayOfPhase,
          field: selectedField,
        )
      : 'No data';

    // add this wherever need graph 



final Map<String, double> phaseStartX = {};
final Map<String, double> phaseEndX = {};

List<FlSpot> estrogenSpots = [];
double xEstrogen = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  if (days.isEmpty) continue;

  phaseStartX[phaseName] = xEstrogen;

  for (final day in days) {
    final estrogen = day.getDouble('Level of Estrogen');
    if (estrogen != null) {
      estrogenSpots.add(FlSpot(xEstrogen, estrogen));
      xEstrogen += 1;
    }
  }

  phaseEndX[phaseName] = xEstrogen - 1;
}


List<FlSpot> progesteroneSpots = [];
double xProgesterone = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final progesterone = day.getDouble('Level of Progesterone');
    if (progesterone != null) {
      progesteroneSpots.add(FlSpot(xProgesterone, progesterone));
      xProgesterone += 1;
    }
  }
}

List<FlSpot> fshSpots = [];
double xFsh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final fsh = day.getDouble('Level of FSH');
    if (fsh != null) {
      fshSpots.add(FlSpot(xFsh, fsh));
      xFsh += 1;
    }
  }
}

List<FlSpot> lhSpots = [];
double xLh = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final lh = day.getDouble('Level of LH');
    if (lh != null) {
      lhSpots.add(FlSpot(xLh, lh));
      xLh += 1;
    }
  }
}
final maxX = [
  estrogenSpots,
  progesteroneSpots,
  fshSpots,
  lhSpots,
]
    .where((list) => list.isNotEmpty)
    .map((list) => list.last.x)
    .fold<double>(0.0, (prev, x) => x > prev ? x : prev);




List<FlSpot> energySpots = [];
double xEnergy = 0;

for (final phaseName in phasesInOrder) {
  final days = cycleData.getAllPhaseDays(phaseName);

  for (final day in days) {
    final energy = day.getDouble('Energy Levels');
    if (energy != null) {
      energySpots.add(FlSpot(xEnergy, energy));
      xEnergy += 1;
    }
  }
}

final phaseColors = {
  'Menstruation': const Color.fromARGB(64, 217, 28, 56),
  'Follicular': const Color.fromRGBO(173, 216, 230, 0.25),
  'Ovulation': const Color.fromRGBO(144, 238, 144, 0.25), 
  'Early Luteal': const Color.fromRGBO(221, 160, 221, 0.25),
  'Late Luteal': const Color.fromRGBO(255, 228, 181, 0.25),
};
// design change these to match color scheme

final highlightedPhase = "Late Luteal";
final List<VerticalRangeAnnotation> phaseAnnotations =
    (phaseStartX.containsKey(highlightedPhase) &&
     phaseEndX.containsKey(highlightedPhase))
        ? [
            VerticalRangeAnnotation(
              x1: phaseStartX[highlightedPhase]!,
              x2: phaseEndX[highlightedPhase]!,
              color: (phaseColors[highlightedPhase] ?? const Color.fromARGB(144, 141, 35, 217))
                  .withOpacity(0.35),
            ),
          ]
        : [];

    return Scaffold(
      body: SafeArea(
      child:
      SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: 
      // Container(
      //   width: double.infinity,
      //   padding: const EdgeInsets.all(20.0),
        // child: 
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LATE LUTEAL',
              style: TextStyle(
                color: const Color(0xFF5454CA),
                fontSize: 36,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                height: 0.67,
                letterSpacing: 1.44,
                ),
            ),
            SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child:
              Text(
                'Information',
                style: TextStyle(
                  color:  Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                ),
              )
            ),

            SizedBox(height: 16),

            SizedBox(
              height: 120, // controls button size
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildButton(
                    context,
                    "Phase Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Estrogen",
                    const MenstruationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of Progesterone",
                    const FolicularPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of FSH",
                    const OvulationPage(),
                  ),
                  _buildButton(
                    context,
                    "Effects of LH",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Energy Levels Info",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "What to eat",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Foods and Recipes",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Concentration",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Health",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Mood",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Types of Vitamins",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Brain",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Ovaries",
                    const EarlyLutealPage(),
                  ),
                  _buildButton(
                    context,
                    "Insights in the Uterus",
                    const EarlyLutealPage(),
                  )
                ],
              ),
            ),
          SizedBox(height:20),
        if (hormoneGraph)...[
              Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                
                child: 
                Column(
                  children: [
                    Row(
                      children: const [ // design
        _LegendItem(color:  Color.fromARGB(255, 230, 113, 152), label: 'Estrogen'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.deepPurple, label: 'Progesterone'),
        SizedBox(width: 16),
               _LegendItem(color: Color.fromARGB(255, 114, 243, 107), label: 'FSH'),
        SizedBox(width: 16),
        _LegendItem(color: Color.fromARGB(255, 82, 102, 216), label: 'LH'),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Hormone Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            
                            LineChartBarData(
  spots: estrogenSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 230, 113, 152)
      .withOpacity(isSelected('Effects of Estrogen') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Estrogen') ? 2.5 : 2,
),
                            LineChartBarData(
  spots: progesteroneSpots,
  isCurved: false,
  color: Colors.deepPurple
      .withOpacity(isSelected('Effects of Progesterone') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of Progesterone') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: lhSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 111, 174, 237)
      .withOpacity(isSelected('Effects of LH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of LH') ? 2.5 : 2,
),

                            LineChartBarData(
  spots: fshSpots,
  isCurved: false,
  color: const Color.fromARGB(255, 114, 243, 107)
      .withOpacity(isSelected('Effects of FSH') ? 1.0 : 0.25),
  dotData: FlDotData(show: false),
  barWidth: isSelected('Effects of FSH') ? 2.5 : 2,
),

                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),],
if (energyGraph)...[
Align(
                alignment: Alignment.centerLeft,
                child:
                Text(
                'Graph',
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

              SizedBox(
                height: 350,
                // padding: const EdgeInsets.only(top: 20.0),
                child: SizedBox(height: 300,
                child: 
                Column(
                  children: [
                    Row(
                      children: const [
        _LegendItem(color:  Color.fromARGB(255, 40, 71, 227), label: 'Energy Level'),
        SizedBox(width: 16),
      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:300,
                      child: LineChart(
                      
                        LineChartData(
                          minX: 0,
                          maxX: maxX,
                          minY: 0,

                          rangeAnnotations: RangeAnnotations(
  verticalRangeAnnotations: phaseAnnotations,
),

                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Cycle Day',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameWidget: const Padding(
                                  padding: EdgeInsets.only(right: 20),
                                  child: Text(
                                    'Energy Level',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                            ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: energySpots,
                              isCurved: false,
                              color: const Color.fromARGB(255, 40, 71, 227),
                              dotData: FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                ),
              ),
],
 SizedBox(height:20),

          Align(
            alignment: Alignment.centerLeft,
                child:
                Text(
                'Explanation', //change this
                style: TextStyle(
                  color: const Color(0xFF404446),
                  fontSize: 18,
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.33,
                  ),
                  )
              ),

             Padding(
  padding: const EdgeInsets.only(top: 20.0),
  child: FutureBuilder<String>(
      future: _loadLateLutealInfo(selectedField),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _infoTile(title: selectedField, value: 'Error loading data');
        }

        return _infoTile(
          title: selectedField,
          value: snapshot.data ?? 'No data',
        );
    
      },
      )
    
  ),
]
)
)
      ));
}

//this one doesnt need an icon
  Widget _infoTile({
    required String title,
    required String value,
    //required IconData icon,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Icon(icon, color: const Color.fromARGB(255, 112, 161, 217)),
          // const SizedBox(width: 15),
          Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _buildButton(BuildContext context, String label, Widget page) {
    final selectedField = context.watch<CycleDataProvider>().selectedField;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 160, // controls how many buttons fit on screen
        child: HorizontalScrollButton( // make a new class with a different deign for these
          label: label,
          isSelected: selectedField == label,
          onPressed: () {
            context.read<CycleDataProvider>().selectField(label);
            // Navigator.push();
            //MaterialPageRoute(builder: (_) => page),
            
          },
        ),
      ),
    );
  }
}

// design + functionality for Select Date and Submit buttons 
class SelectButton extends StatelessWidget {
  final String label; // 
  final VoidCallback onPressed;

  const SelectButton({
    super.key,
    required this.label, // cand chemi functia ai nevoie de asta neaparat
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return Container (
      width: 130.0,
      height: 43.0,
      child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8), // design
      child:Container(
        decoration: BoxDecoration( // design
          color: Color(0xFF121D41), // design
          borderRadius: BorderRadius.circular(8), // design
        ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            //mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Column(
              mainAxisAlignment: MainAxisAlignment.center,  
              children: [
                Text(label, // do not change label pls
                style: const TextStyle( // design
                color: Colors.white,// design
                fontSize: 16,
                fontFamily: 'DMSans'
                          ),
                          ),
              ],
            ),],
          ),
        ),

    ),);

  }
}


// text field class
class TextBox extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;

  const TextBox({
    super.key,
    required this.title,
    required this.hint,
    required this.controller,
  });

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title,
        style: TextStyle(
          color: const Color(0xFF1E1E1E) /* Text-Default-Default */,
          fontSize: 16,
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w700,
          height: 1.40,
          ),),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: TextField(
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            controller: controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF1E1E1E),
                fontFamily: 'DMSans',)
            ),
          ),
        ),
      ],
    );
  }
}


class HorizontalScrollButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  const HorizontalScrollButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isSelected,
  });


  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: 137,
      height: 120,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
              ? const Color(0xFFFBE3E4) // color of horizontl scroll button once selected
              : Colors.white, //color of horizontl scroll button not selected
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 20,
                offset: Offset(4, 6),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F8FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon( // change icon of the horizontal scroll buttons - design team
                  Icons.favorite, // replace later if needed
                  size: 16,
                  color: Color(0xFF5454CA),
                ),
              ),

              const SizedBox(height: 12),

              // Label (UNCHANGED)
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF303437),
                  fontSize: 14,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 1.43,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HorizontalScrollButtonPhases extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String colorBox;

  const HorizontalScrollButtonPhases({
    super.key,
    required this.label,
    required this.onPressed,
    required this.colorBox,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 292,
      height: 75,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: colorBox == 'Menstruation' ? Color(0xFFFBE3E4) :
                   colorBox == 'Follicular' ? Color(0xFFF9EDFB) :
                   colorBox == 'Ovulation' ? Color(0xFFE4EFF7) :
                   colorBox == 'Early Luteal' ? Color(0xFFFFF3E2) :
                   colorBox == 'Late Luteal' ? Color(0xFFECEEFF) :
                   Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 40,
                offset: Offset(4, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F8FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.favorite, // replace later if needed
                  size: 16,
                  color: Color(0xFF5454CA),
                ),
              ),

              const SizedBox(height: 12),

              // Label 
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF5454CA),
                  fontSize: 18,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w700,
                  height: 0.67,
                  letterSpacing: 0.72,
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
