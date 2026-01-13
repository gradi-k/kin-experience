class ContactInfo {
  final String? address;
  final String? phone;
  final String? email;
  final String? website;

  const ContactInfo({
    this.address,
    this.phone,
    this.email,
    this.website,
  });

  factory ContactInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ContactInfo();
    return ContactInfo(
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      website: map['website'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
  }..removeWhere((k, v) => v == null);

  bool get isEmpty =>
      (address == null || address!.trim().isEmpty) &&
          (phone == null || phone!.trim().isEmpty) &&
          (email == null || email!.trim().isEmpty) &&
          (website == null || website!.trim().isEmpty);
}
