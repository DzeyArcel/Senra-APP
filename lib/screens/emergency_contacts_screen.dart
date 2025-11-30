import 'package:flutter/material.dart';
import 'package:senra_app/screens/add_contact_modal.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

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
              // ---------------- TOP BAR ----------------
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white70, size: 22),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Emergency\nContacts",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),

            GestureDetector(
  onTap: () {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddContactModal(),
    );
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF33B5FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Icon(Icons.add, color: Colors.white, size: 18),
        SizedBox(width: 4),
        Text(
          "Add Contact",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        )
      ],
    ),
  ),
),

                ],
              ),

              const SizedBox(height: 6),
              const Text(
                "Manage your emergency contact list",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 20),

              // ---------------- CONTACT CARD 1 ----------------
             _contactCard(
  name: "John Doe",
  relation: "Son",
  phone: "(555) 123-4567",
  email: "john.doe@email.com",
  onEdit: () {
    Navigator.pushNamed(context, '/edit-contact');
  },
  onDelete: () {
    // Later: show delete modal
  },
),

              // ---------------- CONTACT CARD 2 ----------------
             _contactCard(
  name: "Jane Smith",
  relation: "Daughter",
  phone: "(555) 987-6543",
  email: "jane.smith@email.com",
  onEdit: () {
    Navigator.pushNamed(context, '/edit-contact');
  },
  onDelete: () {},
),

              // ---------------- HOW IT WORKS ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How it works",
                      style: TextStyle(
                          color: Color(0xFF33B5FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),
                    _bullet("- Emergency contacts are notified when a fall is detected"),
                    SizedBox(height: 6),
                    _bullet(
                        "- Location information is automatically shared during alerts"),
                    SizedBox(height: 6),
                    _bullet(
                        "- Contact information is verified during emergency situations"),
                    SizedBox(height: 6),
                    _bullet(
                        "- All registered contacts receive immediate notifications"),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

 
 Widget _contactCard({
  required String name,
  required String relation,
  required String phone,
  required String email,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF162233),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),

            // Relation Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                relation,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),

            const Spacer(),

            // ----------- EDIT BUTTON ----------
            GestureDetector(
              onTap: onEdit,
              child: const Icon(Icons.edit,
                  color: Color(0xFF33B5FF), size: 20),
            ),

            const SizedBox(width: 12),

            // ----------- DELETE BUTTON ----------
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete,
                  color: Colors.redAccent, size: 20),
            ),
          ],
        ),

        const SizedBox(height: 4),
        const Text(
          "Emergency Contact",
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            const Icon(Icons.phone, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(phone, style: const TextStyle(color: Colors.white)),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            const Icon(Icons.mail, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(email, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ],
    ),
  );
}

}

  


// BULLET POINT ROW ----------------------------------------
class _bullet extends StatelessWidget {
  final String text;
  const _bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
    );
  }
}
