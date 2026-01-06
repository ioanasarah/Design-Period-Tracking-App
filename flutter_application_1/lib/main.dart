import 'package:flutter/material.dart';

/// Flutter code sample for basic [showDatePicker].

void main() => runApp(const LogPage());

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
              onPressed: () {
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


class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placeholder'),
      ),
      body: Center(
        child: ButtonWidget()
        //Text('Next page placeholder'),
      ),
    );
  }
}


class ButtonWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
          // Figma Flutter Generator ButtonWidget - INSTANCE
            return Container(
      width: 98,
      height: 48,
      
      child: Stack(
        children: <Widget>[
          Positioned(
        top: 4,
        left: 1.5,
        child: Container(
      decoration: BoxDecoration(
          borderRadius : BorderRadius.only(
            topLeft: Radius.circular(100),
            topRight: Radius.circular(100),
            bottomLeft: Radius.circular(100),
            bottomRight: Radius.circular(100),
          ),
      color : Color.fromRGBO(103, 80, 164, 1),
  ),
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        
        children: <Widget>[Container(
      decoration: BoxDecoration(
          
  ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        
        children: <Widget>[
          SizedBox(width : 8),
Text('Label', textAlign: TextAlign.left, style: TextStyle(
        color: Color.fromRGBO(255, 255, 255, 1),
        fontFamily: 'Roboto',
        fontSize: 14,
        letterSpacing: 0.10000000149011612,
        fontWeight: FontWeight.normal,
        height: 1.4285714285714286
      ),),

        ],
      ),
    ),
],
      ),
    )
      ),
        ]
      )
    );
          }
        }
        