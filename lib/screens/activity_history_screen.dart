import 'package:flutter/material.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70, size: 22),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Activity &\nHistory",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),

                  // CLEAR ALL BUTTON
                  GestureDetector(
                    onTap: () => _showClearAllDialog(context),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF33B5FF)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline,
                              size: 16, color: Color(0xFF33B5FF)),
                          SizedBox(width: 6),
                          Text(
                            "Clear All",
                            style: TextStyle(
                              color: Color(0xFF33B5FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 6),
              const Text(
                "Timeline of events and alerts",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 22),

              // ACTIVITY CARDS -------------------------
              _activityCard(
                context,
                type: "Fall Detected",
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.redAccent,
                status: "Alert Sent",
                time: "2024-01-15 14:23",
                address: "123 Main Street, San Francisco, CA",
                contacts: ["John Doe", "Jane Smith"],
                note: null,
              ),

              const SizedBox(height: 16),

              _activityCard(
                context,
                type: "Manual SOS",
                icon: Icons.phone_in_talk_rounded,
                iconColor: Colors.lightBlueAccent,
                status: "Cancelled",
                time: "2024-01-14 09:15",
                address: "456 Oak Avenue, San Francisco, CA",
                contacts: [],
                note:
                    "User confirmed they were safe before alert was sent",
              ),

              const SizedBox(height: 16),

              _activityCard(
                context,
                type: "Fall Detected",
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.redAccent,
                status: "Alert Sent",
                time: "2024-01-12 16:45",
                address: "789 Pine Street, San Francisco, CA",
                contacts: ["John Doe", "Emergency Services"],
                note: null,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // ACTIVITY CARD WIDGET (Matches Figma perfectly)
  // ---------------------------------------------------------------------

  Widget _activityCard(
    BuildContext context, {
    required String type,
    required IconData icon,
    required Color iconColor,
    required String status,
    required String time,
    required String address,
    required List<String> contacts,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE ROW with Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 10),
                  Text(type,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              Text(status,
                  style: TextStyle(
                    color: status == "Alert Sent"
                        ? Colors.lightBlueAccent
                        : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              GestureDetector(
                onTap: () => _showDeleteDialog(context),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // TIME
          Row(
            children: [
              const Icon(Icons.access_time,
                  color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(time,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 14),

          // ADDRESS
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(address,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),

          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("Contacts Notified:",
                style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: contacts
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            )
          ],

          if (note != null) ...[
            const SizedBox(height: 16),
            Text(
              note,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DELETE ONE ACTIVITY DIALOG
  // ---------------------------------------------------------------------

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Center(
          child: Text("Delete Activity?",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        ),
        content: const Text(
          "This will permanently delete this activity record.\nThis action cannot be undone.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // DELETE BUTTON
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text("Delete",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 10),

          // CANCEL
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF223247),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text("Cancel",
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // CLEAR ALL HISTORY DIALOG
  // ---------------------------------------------------------------------

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Center(
          child: Text("Clear All History?",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        ),
        content: const Text(
          "This will permanently delete all activity history.\nThis action cannot be undone.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text("Delete All",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 10),

          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF223247),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text("Cancel",
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
