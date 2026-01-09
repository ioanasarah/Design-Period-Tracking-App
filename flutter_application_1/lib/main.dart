import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle, TextInputFormatter, FilteringTextInputFormatter;
import 'dart:convert';
//import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => Calculate(),
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
  'menstrual': 'assets/Menstrual_Phase.json',
  'follicular': 'assets/Follicular_Phase.json',
  'ovulation': 'assets/Ovulation_Phase.json',
  'early_luteal': 'assets/Early_Luteal_Phase.json',
  'late_luteal': 'assets/Late_Luteal_Phase.json',
};


//load JSON file
Future<List<Map<String, dynamic>>> loadCycleData() async {
  final jsonString = await rootBundle.loadString('assets/Menstrual_Phase.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.cast<Map<String, dynamic>>();
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
            label: 'Home',
            // icon: 'assets/images/vector.svg',
            icon: Icons.home, // icon for tabs 
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _NavButton(
            label: 'Information',
            // icon: 'assets/images/vector.svg',
            // icon: Icon(Icons.info).toString(),
            icon: Icons.info,
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _NavButton(
            label: 'Stats',
            // icon: 'assets/images/vector.svg',
            icon: Icons.school,
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          _NavButton(
            label: 'Settings',
            // icon: 'assets/images/vector.svg',
            icon: Icons.business,
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
              ? const Color.fromRGBO(53, 18, 58, 1)
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
                  fontFamily: 'DM Sans',
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

  int _selectedIndex = 0;

  // Top-level pages only
  List<Widget> get _pages => [
  LogPage(onSubmit: () => _onItemTapped(1)),
  const PlaceholderPage(),
  const Center(child: Text('Insights')),
  const Center(child: Text('Settings')),
];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
    title: const Text("Log your Period Details!"),
    ),
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
    return LogCalendar(onSubmit: onSubmit);
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
                fontFamily: 'DM Sans',
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
                      fontFamily: 'DM Sans',
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
            
            TextBox(
                  title: "Average period length (days):",
                  hint: "Enter number of days",
                  controller: periodLengthController,
                ),

            TextBox(
                  title: "Average cycle length (days):",
                  hint: "Enter number of days",
                  controller: cycleLengthController,
                ),

            SelectButton(
                  label: 'Submit',
                  onPressed: () async {
                    if (selectedDate == null) return;

                    final int periodLength =
                        int.tryParse(periodLengthController.text) ?? 0;
                    final int cycleLength =
                        int.tryParse(cycleLengthController.text) ?? 0;

                    final calc = context.read<Calculate>();

                    calc.calculateNextPeriod(selectedDate!, cycleLength);
                    calc.calculateDayOfCycle(selectedDate!);
                    calc.determinePhase(
                      cycleDay: calc.difference!,
                      cycleLength: cycleLength,
                      periodLength: periodLength,
                    );
                    // await calc.calculatePhase();

                    widget.onSubmit();
                  
                  },
                ),
          ],
        
        ),
    
    );
  }
  //child: const Text("Submit"),

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
      width: 120.0,
      height: 45.0,
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
                fontFamily: 'DM Sans'
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
        style: TextStyle(
          color: const Color(0xFF1E1E1E) /* Text-Default-Default */,
          fontSize: 16,
          fontFamily: 'DM Sans',
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
                fontFamily: 'DM Sans',)
            ),
          ),
        ),
      ],
    );
  }
}


class Calculate extends ChangeNotifier {
  DateTime? nextPeriodDate;
  int? difference;
  String? phase;
  int? dayofphase;


  void calculateNextPeriod(DateTime lastPeriodDate, int periodLength) {
    nextPeriodDate = lastPeriodDate.add(Duration(days: periodLength));
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
      phase = 'menstrual';
      dayofphase = cycleDay;
    } else if (cycleDay < ovulationDay) {
      phase  =  'follicular';
      dayofphase = cycleDay - periodLength;
    } else if (cycleDay == ovulationDay) {
      phase = 'ovulation';
      dayofphase = ovulationDay;
    } else if (cycleDay <= ovulationDay + 6) {
      phase = 'early_luteal';
      dayofphase = cycleDay - ovulationDay;
    } else {
      phase = 'late_luteal';
      dayofphase = cycleDay - ovulationDay - 6;
    }
    // return phase!;
    notifyListeners();
}

  }



class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Accessing the data from your Calculate provider
    final calc = context.watch<Calculate>();
    final nextPeriodDate = calc.nextPeriodDate;
    final difference = calc.difference;
    final phase = calc.phase;
    final dayofphase = calc.dayofphase;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Cycle Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(54, 18, 58, 1),
            ),
          ),
          const SizedBox(height: 30),
          
          // Next Period Card
          _infoTile(
            title: 'Next Expected Period',
            value: nextPeriodDate != null
                ? '${nextPeriodDate.day}/${nextPeriodDate.month}/${nextPeriodDate.year}'
                : 'Not calculated',
            icon: Icons.calendar_today,
          ),

          // Day of Cycle Card
          _infoTile(
            title: 'Days Since Last Period',
            value: difference != null ? '$difference Days' : 'Pending',
            icon: Icons.timer,
          ),

          // Current Phase Card
          _infoTile(
            title: 'Current Phase',
            value: phase ?? 'Data missing',
            icon: Icons.home,
            //isHighlighted: true,
          ),
          _infoTile(
            title: 'Day Of $phase Phase',
            value: dayofphase != null ? '$dayofphase' : 'Data missing',
            icon: Icons.heart_broken,
            //isHighlighted: true,
          ),
        ],
      ),
    );
  }

  // Helper widget to keep the code clean
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
        color: isHighlighted ? const Color.fromRGBO(54, 18, 58, 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromRGBO(54, 18, 58, 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromRGBO(54, 18, 58, 1)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
