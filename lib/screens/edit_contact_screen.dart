import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditContactScreen extends StatefulWidget {
  const EditContactScreen({super.key});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  String caregiverId = "";
  String contactId = "";

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromArgs());
  }

  // ------------------------------------------------------------
  // NORMALIZE PH NUMBER
  // ------------------------------------------------------------

  String normalizePHNumber(String phone) {

    phone = phone.trim();

    if (phone.startsWith("09")) {
      return "+63${phone.substring(1)}";
    }

    if (phone.startsWith("639")) {
      return "+$phone";
    }

    if (phone.startsWith("+63")) {
      return phone;
    }

    return phone;
  }

  // ------------------------------------------------------------
  // LOAD CONTACT DATA
  // ------------------------------------------------------------

  Future<void> _loadFromArgs() async {

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    contactId = args?["contactId"] ?? "";

    nameController.text = args?["name"] ?? "";
    phoneController.text = args?["phone"] ?? "";
    emailController.text = args?["email"] ?? "";
    relationController.text = args?["relation"] ?? "";

    final prefs = await SharedPreferences.getInstance();
    caregiverId = prefs.getString("caregiverId") ?? "";

    setState(() => loading = false);
  }

  // ------------------------------------------------------------
  // SYNC CONTACTS TO DEVICE
  // ------------------------------------------------------------

  Future<void> _syncDeviceNumbers() async {

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId.isEmpty) return;

    final contacts = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .limit(2)
        .get();

    String ownerPhone = "";
    String emergencyPhone = "";

    if (contacts.docs.isNotEmpty) {
      ownerPhone = contacts.docs[0]["phone"];
    }

    if (contacts.docs.length > 1) {
      emergencyPhone = contacts.docs[1]["phone"];
    }

    await FirebaseFirestore.instance
        .collection("devices")
        .doc(deviceId)
        .set({
      "ownerPhone": ownerPhone,
      "emergencyPhone": emergencyPhone,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ------------------------------------------------------------
  // SAVE CHANGES
  // ------------------------------------------------------------

  Future<void> _saveChanges() async {

    if (caregiverId.isEmpty || contactId.isEmpty) return;

    final name = nameController.text.trim();
    String phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final relation = relationController.text.trim();

    if (name.isEmpty || phone.isEmpty || relation.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name, phone and relationship are required."),
          backgroundColor: Colors.redAccent,
        ),
      );

      return;
    }

    phone = normalizePHNumber(phone);

    setState(() => saving = true);

    try {

      await FirebaseFirestore.instance
          .collection("caregivers")
          .doc(caregiverId)
          .collection("contacts")
          .doc(contactId)
          .update({

        "name": name,
        "phone": phone,
        "email": email,
        "relation": relation,
        "updatedAt": FieldValue.serverTimestamp(),

      });

      await _syncDeviceNumbers();

      if (!mounted) return;
      Navigator.pop(context);

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save changes."),
          backgroundColor: Colors.redAccent,
        ),
      );

    }

    if (mounted) setState(() => saving = false);
  }

  // ------------------------------------------------------------
  // DELETE CONTACT
  // ------------------------------------------------------------

  Future<void> _deleteContact() async {

    if (caregiverId.isEmpty || contactId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Delete Contact?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This emergency contact will be removed.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .collection("contacts")
        .doc(contactId)
        .delete();

    await _syncDeviceNumbers();

    if (!mounted) return;
    Navigator.pop(context);
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF33B5FF)),
        ),
      );
    }

    return Scaffold(

      backgroundColor: const Color(0xFF0E1625),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(
                children: [

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,color: Colors.white70),
                  ),

                  const Text(
                    "Edit Contact",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              _label("Full Name *"),
              _inputField(nameController),

              const SizedBox(height: 16),

              _label("Phone Number *"),
              _inputField(phoneController,isPhone:true),

              const SizedBox(height: 16),

              _label("Email"),
              _inputField(emailController),

              const SizedBox(height: 16),

              _label("Relationship *"),
              _inputField(relationController),

              const SizedBox(height: 24),

              Row(
                children: [

                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving ? null : _saveChanges,
                      child: Text(saving ? "Saving..." : "Save Changes"),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deleteContact,
                      child: const Text("Delete Contact"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _inputField(TextEditingController controller,{bool isPhone=false}) {

    return Container(

      decoration: BoxDecoration(
        color: const Color(0xFF101B2C),
        borderRadius: BorderRadius.circular(10),
      ),

      child: TextField(

        controller: controller,

        style: const TextStyle(color: Colors.white),

        keyboardType:
            isPhone ? TextInputType.phone : TextInputType.text,

        inputFormatters:
            isPhone ? [FilteringTextInputFormatter.digitsOnly] : [],

        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}