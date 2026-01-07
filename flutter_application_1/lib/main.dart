import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
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
      home: const NavigationBar(),
    );
  }
}


//load JSON file
Future<List<Map<String, dynamic>>> loadCycleData() async {
  final jsonString = await rootBundle.loadString('assets/phase_info.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.cast<Map<String, dynamic>>();
}

class NavigationBar extends StatefulWidget {
  const NavigationBar({super.key});

  @override
  State<NavigationBar> createState() => _NavigationBarState();
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
    return Container(
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
            icon: Icons.home,
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _NavButton(
            label: 'Info',
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
              ? const Color.fromRGBO(48, 52, 55, 1)
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
                    : Colors.grey,
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


class _NavigationBarState
    extends State<NavigationBar> {

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
  
  const LogPage({
    super.key, 
    required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('When did your last period start?')),
        body: Center(child: DatePickerExample(onSubmit: onSubmit)),
      );
  }
}



//calendar
class DatePickerExample extends StatefulWidget {
  final VoidCallback onSubmit;

  const DatePickerExample({super.key, required this.onSubmit});
  @override
  State<DatePickerExample> createState() => _DatePickerExampleState();
}

class _DatePickerExampleState extends State<DatePickerExample> {
  DateTime? selectedDate;

  DateTime now = new DateTime.now();

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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 20,
      children: <Widget>[
        Text(
          selectedDate != null
              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
              : 'No date selected',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectButton(
              label: 'Select Date',
              onPressed: _selectDate,
            ),
            SelectButton(
              label: 'Submit',
              onPressed: () async { // async pentru await
                if (selectedDate == null) return;
                
                final calc = context.read<Calculate>();
                calc.calculateNextPeriod(selectedDate!);
                calc.calculateDayOfCycle(selectedDate!);
                await calc.calculatePhase();

                widget.onSubmit();
              
              },
            ),
          ],
      
      ),
      ],

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
    return InkWell (
      onTap: onPressed,
      borderRadius: BorderRadius.circular(100), // design
      child:Container(
        decoration: BoxDecoration( // design
          color: Color.fromRGBO(54,18, 58, 1), // design
          borderRadius: BorderRadius.circular(100), // design
        ),
          padding: const EdgeInsets.symmetric( // design
            horizontal: 16, // design
            vertical: 10,),
          child: Center(
            child: Text(label, // do not change label pls
          style: const TextStyle( // design
            color: Colors.white,// design
            fontSize: 14,// design
          ),
          ),
          ),
        ),
    );
  }
}


class Calculate extends ChangeNotifier {
  DateTime? nextPeriodDate;
  int? difference;
  String? phase;
  void calculateNextPeriod(DateTime lastPeriodDate) {
    nextPeriodDate = lastPeriodDate.add(const Duration(days: 28));
    notifyListeners();}
  
  void calculateDayOfCycle(DateTime lastPeriodDate) {
    final today = DateTime.now();
    difference = today.difference(lastPeriodDate).inDays;
    notifyListeners();
  }
  Future <void> calculatePhase() async {
    if (difference == null) return;
    final cycleData = await loadCycleData();
    final entry = cycleData.firstWhere(
      (e) => e["Day of cycle"] == difference,
      orElse: () => {"Phase": "Unknown"},
    );
    phase = entry["Phase"];
    notifyListeners();
  }
  }



class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});
  

  @override
  Widget build(BuildContext context) {
    //context.read<NavigationState>().goTo(1);
    final nextPeriodDate = context.watch<Calculate>().nextPeriodDate;
    final difference = context.watch<Calculate>().difference;
    final phase = context.watch<Calculate>().phase;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day info'),
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text(
              nextPeriodDate != null
                ? 'Your next period is expected on: ${nextPeriodDate!.day}/${nextPeriodDate!.month}/${nextPeriodDate!.year}'
                : 'Next period date not calculated yet.',
            //child: ButtonWidget(),
            //child: Text('Next page placeholder'),
          ),
          Text(difference != null
                ? 'Days since last period: $difference'
                : 'Day of cycle not calculated yet.',
            ),
            Text(phase != null ? 'Current phase: $phase' : 'Phase not calculated yet.'
            ),
          ],
          ),
        ],
      ),
  
    );
  }
}