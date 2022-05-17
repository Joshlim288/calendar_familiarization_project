import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'add_event_page.dart';
import 'event_model.dart';

class CalendarPage extends StatefulWidget {
  CalendarPage({required this.box});
  Box<Event> box;
  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  late List<Event> eventList;
  List<String> expandedEventIds = [];
  final DateFormat multiDayFormatter = DateFormat('dd E');
  final DateFormat dayNumFormatter = DateFormat('dd');
  final DateFormat dayTextFormatter = DateFormat('E');
  final DateFormat timeFormatter = DateFormat('hh:mm');
  late DateTime focusedDay;
  DateTime? selectedDay;
  List<Event>? selectedEvents;

  @override
  void initState() {
    super.initState();
    // for robustness, if Hive has issue
    loadData();
    focusedDay = DateTime.now();
    selectedDay = DateTime.now();
  }

  void loadData() {
    try {
      eventList = widget.box.values.toList();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error loading event data', // message
        toastLength: Toast.LENGTH_SHORT, // length
        gravity: ToastGravity.BOTTOM, // location
      );
      eventList = <Event>[];
    }
  }

  List<Event> getEventsForDay(DateTime day) {
    return eventList
        .where(
          (Event event) => event.startTime.day <= day.day && day.day <= event.endTime.day && event.startTime.month <= day.month && day.month <= event.endTime.month && event.startTime.year <= day.year && day.year <= event.endTime.year,
        )
        .toList();
  }

  onDaySelected(DateTime newSelectedDay, DateTime newFocusedDay) {
    setState(() {
      selectedDay = newSelectedDay;
      focusedDay = newFocusedDay;
      selectedEvents = getEventsForDay(newSelectedDay);
    });
  }

  confirmDelete(String name, String eventKey) {
    showDialog(
      context: context, barrierDismissible: false, // user must tap button!

      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Delete event $name?'),
          actions: [
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                widget.box.delete(eventKey);
                Navigator.of(context).pop();
                setState(() {});
              },
            ),
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    // refresh selection and list of events on every build
    onDaySelected(selectedDay ?? DateTime.now(), focusedDay);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2010),
            lastDay: DateTime(2030),
            focusedDay: focusedDay,
            selectedDayPredicate: (DateTime day) {
              return isSameDay(selectedDay, day);
            },
            onDaySelected: onDaySelected,
            onPageChanged: (DateTime newFocusedDay) {
              focusedDay = newFocusedDay;
            },
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'month'},
            eventLoader: (DateTime day) {
              return getEventsForDay(day);
            },
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
            ),
          ),
          // List of events
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: selectedEvents?.length ?? 0,
              itemBuilder: (BuildContext context, int index) {
                return Card(
                  child: ExpansionTile(
                    key: Key(selectedEvents![index].eventKey), //attention
                    initiallyExpanded: expandedEventIds.contains(selectedEvents![index].eventKey), //attention
                    leading: SizedBox(
                        width: 50,
                        child: (selectedEvents![index].startTime.day != selectedEvents![index].endTime.day)
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(multiDayFormatter.format(selectedEvents![index].startTime)),
                                  const Icon(Icons.arrow_downward),
                                  Text(multiDayFormatter.format(selectedEvents![index].endTime)),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    dayNumFormatter.format(selectedEvents![index].startTime),
                                    textAlign: TextAlign.center,
                                    textScaleFactor: 1.5,
                                  ),
                                  Text(
                                    dayTextFormatter.format(selectedEvents![index].startTime),
                                    textAlign: TextAlign.center,
                                    textScaleFactor: 1.15,
                                  ),
                                ],
                              )),
                    title: Text(selectedEvents![index].name),
                    subtitle: selectedEvents![index].fullDay
                        ? const Text('Full Day')
                        : Text(
                            '${timeFormatter.format(selectedEvents![index].startTime)} to ${timeFormatter.format(selectedEvents![index].endTime)}',
                          ),
                    trailing: (expandedEventIds.contains(selectedEvents![index].eventKey)) ? const Icon(Icons.arrow_drop_up_outlined) : const Icon(Icons.arrow_drop_down_outlined),
                    children: <Widget>[
                      ListTile(
                        title: Text(selectedEvents![index].comment),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_calendar_outlined),
                              onPressed: () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (BuildContext context) => EventPage(
                                          selectedDay: selectedDay,
                                          editEventKey: selectedEvents![index].eventKey,
                                          eventBox: widget.box,
                                        ),
                                      ),
                                    )
                                    .then((value) => setState(() {})); // so that page is reloaded on return
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                confirmDelete(selectedEvents![index].name, selectedEvents![index].eventKey);
                              },
                            )
                          ],
                        ),
                      ),
                    ],
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        String id = selectedEvents![index].eventKey;
                        if (expandedEventIds.contains(id)) {
                          expandedEventIds.remove(id);
                        } else {
                          expandedEventIds.add(id);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Event',
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (BuildContext context) => EventPage(
                    selectedDay: selectedDay,
                    eventBox: widget.box,
                  ),
                ),
              )
              .then((value) => setState(() {})); // so that page is reloaded on return
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
