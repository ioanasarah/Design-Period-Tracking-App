import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';


/// Flutter code sample for basic [showDatePicker]


//load JSON file
Future<List<Map<String, dynamic>>> loadCycleData() async {
  final jsonString = await rootBundle.loadString('assets/phase_info.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.cast<Map<String, dynamic>>();
}

class BottomNavigationBarExampleApp extends StatelessWidget {
  const BottomNavigationBarExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
   // return const MaterialApp(home: BottomNavigationBarExample());
    return const MaterialApp(home: LogPage());
  }
}

class BottomNavigationBarExample extends StatefulWidget {
  const BottomNavigationBarExample({super.key});

  @override
  State<BottomNavigationBarExample> createState() => _BottomNavigationBarExampleState();
}

class _BottomNavigationBarExampleState extends State<BottomNavigationBarExample> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle = TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
  static const List<Widget> _widgetOptions = <Widget>[
    Text('Index 0: Home', style: optionStyle),
    Text('Index 1: Business', style: optionStyle),
    Text('Index 2: School', style: optionStyle),
    Text('Index 3: Settings', style: optionStyle),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BottomNavigationBar Sample')),
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            backgroundColor: Colors.red,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Business',
            backgroundColor: Colors.green,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'School',
            backgroundColor: Colors.purple,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
            backgroundColor: Colors.pink,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => Calculate(),
      child: const LogPage(),
    ),
  );
}
// whole first page
class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('When did your last period start?')),
        body: const Center(child: DatePickerExample()),
      ),
    );
  }
}
//calendar
class DatePickerExample extends StatefulWidget {
  const DatePickerExample({super.key});

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

                Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => const PlaceholderPage(),
      ),
    );
  },
  //child: const Text("Submit"),
),
          ],
        ),
        
      ],
      
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
    return InkWell (
      onTap: onPressed,
      borderRadius: BorderRadius.circular(100), // design
      child:Container(
        decoration: BoxDecoration( // design
          color: Color.fromRGBO(164, 80, 80, 1), // design
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

