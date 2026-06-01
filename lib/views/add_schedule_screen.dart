import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/models/bus_schedule.dart';
import 'package:uni_transit/services/schedule_service.dart';

class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _busNumberController = TextEditingController();
  final _departureTimeController = TextEditingController();

  // Dropdown Values
  String? _selectedRoute;
  String? _selectedType;

  final List<String> _stops = [];
  final _stopsController = TextEditingController();

  final _scheduleService = ScheduleService();
  bool _isLoading = false;

  final List<String> _routeOptions = [
    'Abbasia/Old Campus To Baghdad Campus',
    'Baghdad Campus To Abbasia/Old Campus',
    'Abbasia/Old Campus Via Rafi Qamar Road',
    'Baghdad Campus Via Rafi Qamar Road',
    'Abbasia/Old Campus To Railway Campus',
    'Railway Campus To Abbasia/Old Campus',
    'Railway Campus To Baghdad Campus',
    'Baghdad Campus To Railway Campus',
  ];

  final List<String> _typeOptions = [
    'Boys Special',
    'Girls Special',
    'Combined',
    'Staff Only',
  ];

  void _addStop() {
    if (_stopsController.text.isNotEmpty) {
      setState(() {
        _stops.add(_stopsController.text.trim());
        _stopsController.clear();
      });
    }
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
    });
  }

  void _saveSchedule() async {
    if (_formKey.currentState!.validate() &&
        _stops.isNotEmpty &&
        _selectedRoute != null &&
        _selectedType != null) {
      setState(() => _isLoading = true);

      final newSchedule = BusSchedule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        busNumber: _busNumberController.text.trim(),
        route: _selectedRoute!,
        departureTime: _departureTimeController.text.trim(),
        stops: _stops,
        type: _selectedType!,
      );

      try {
        await _scheduleService.addSchedule(newSchedule);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Schedule Added!")));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields and add at least one stop"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Schedule", style: GoogleFonts.poppins()),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _busNumberController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Bus Numbers",
                  hintText: "e.g. 1, 2, 3 (Comma Separated)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? "Enter Bus Numbers" : null,
              ),
              const SizedBox(height: 10),

              // Route Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRoute,
                decoration: const InputDecoration(
                  labelText: "Route",
                  border: OutlineInputBorder(),
                ),
                items:
                    _routeOptions
                        .map(
                          (route) => DropdownMenuItem(
                            value: route,
                            child: Text(
                              route,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _selectedRoute = val),
                validator: (val) => val == null ? "Select Route" : null,
                isExpanded: true,
              ),
              const SizedBox(height: 10),

              // Type Dropdown (Speciality)
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: "Bus Type",
                  border: OutlineInputBorder(),
                ),
                items:
                    _typeOptions
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _selectedType = val),
                validator: (val) => val == null ? "Select Type" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _departureTimeController,
                textInputAction: TextInputAction.next,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Departure Time",
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                ),
                validator: (val) => val!.isEmpty ? "Select Time" : null,
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primaryNavy,
                            onPrimary: Colors.white,
                            onSurface: AppColors.primaryNavy,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _departureTimeController.text = picked.format(context);
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stopsController,
                      textInputAction: TextInputAction.go,
                      onFieldSubmitted: (_) => _addStop(),
                      decoration: const InputDecoration(
                        labelText: "Add Stop",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _addStop,
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children:
                    _stops.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        onDeleted: () => _removeStop(entry.key),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: AppColors.primaryNavy,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: AppColors.primaryNavy)
                        : const Text("Save Schedule"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

