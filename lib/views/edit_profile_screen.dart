import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = "Utilisateur non connecté.";
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = doc.data();

      // fallback: si Firestore vide → prend displayName Auth (split)
      final display = (user.displayName ?? '').trim();
      String fallbackFirst = "";
      String fallbackLast = "";
      if (display.isNotEmpty) {
        final parts = display.split(" ");
        fallbackFirst = parts.first;
        if (parts.length > 1) {
          fallbackLast = parts.sublist(1).join(" ");
        }
      }

      _firstNameCtrl.text =
      (data?["firstName"] as String?)?.trim().isNotEmpty == true
          ? (data?["firstName"] as String).trim()
          : fallbackFirst;

      _lastNameCtrl.text =
      (data?["lastName"] as String?)?.trim().isNotEmpty == true
          ? (data?["lastName"] as String).trim()
          : fallbackLast;

      _phoneCtrl.text = (data?["phone"] as String?)?.trim() ?? "";

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Impossible de charger le profil.\n$e";
      });
    }
  }

  Future<void> _save() async {
    final user = _user;
    if (user == null) return;

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      setState(() {
        _error = "Veuillez remplir Prénom, Nom et Téléphone.";
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // ✅ Firestore update
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "firstName": firstName,
        "lastName": lastName,
        "phone": phone,
        "email": user.email ?? "",
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ FirebaseAuth displayName update (utile pour UI fallback)
      await user.updateDisplayName("$firstName $lastName");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil mis à jour avec succès."),
          duration: Duration(milliseconds: 1200),
        ),
      );

      Navigator.of(context).pop(true); // ✅ retourne true (profil modifié)
    } catch (e) {
      setState(() {
        _error = "Erreur lors de la sauvegarde.\n$e";
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier le profil"),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],

            _field(
              label: "Prénom",
              controller: _firstNameCtrl,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),

            _field(
              label: "Nom",
              controller: _lastNameCtrl,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 12),

            _field(
              label: "Téléphone",
              controller: _phoneCtrl,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              hint: "+243...",
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  "Enregistrer",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: theme.brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
