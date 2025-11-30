import 'package:flutter/material.dart';

class AddContactModal extends StatelessWidget {
  const AddContactModal({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController relationshipController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF162233),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- HEADER ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Add Emergency Contact",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 4),
          const Text(
            "Add a new person to your emergency contact list",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // ---------- FULL NAME ----------
          const Text("Full Name",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          _inputField(controller: nameController, hint: "Enter full name"),

          const SizedBox(height: 16),

          // ---------- PHONE ----------
          const Text("Phone Number",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          _inputField(controller: phoneController, hint: "(555) 123-4567"),

          const SizedBox(height: 16),

          // ---------- EMAIL ----------
          const Text("Email (Optional)",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          _inputField(controller: emailController, hint: "email@example.com"),

          const SizedBox(height: 16),

          // ---------- RELATIONSHIP ----------
          const Text("Relationship",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          _inputField(
              controller: relationshipController,
              hint: "e.g., Son, Daughter, Friend"),

          const SizedBox(height: 22),

          // ---------- ADD CONTACT BUTTON ----------
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


          const SizedBox(height: 10),

          // ---------- CANCEL BUTTON ----------
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2A3A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ---------- INPUT FIELD UI ----------
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
