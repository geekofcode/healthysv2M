import 'dart:convert';

Map<String, dynamic> summaryJson() =>
    jsonDecode(
          r'''{"id": "rx-1", "prescriptionNumber": "RX-1", "patientId": "patient-1", "consultationId": null, "prescriberId": "doctor-1", "prescriberName": "Médecin", "organizationId": "org-1", "organizationName": "Clinique", "prescribedAt": "2026-10-02T10:00:00Z", "expiresAt": null, "status": "PARTIALLY_DISPENSED", "expired": false}''',
        )
        as Map<String, dynamic>;
Map<String, dynamic> detailJson() =>
    jsonDecode(
          r'''{"prescription": {"id": "rx-1", "prescriptionNumber": "RX-1", "patientId": "patient-1", "consultationId": null, "prescriberId": "doctor-1", "prescriberName": "Médecin", "organizationId": "org-1", "organizationName": "Clinique", "prescribedAt": "2026-10-02T10:00:00Z", "expiresAt": null, "status": "PARTIALLY_DISPENSED", "expired": false}, "items": [{"id": "rxitem-1", "medicationCatalogId": "med-1", "medicationCode": "MED", "medicationName": "Médicament", "genericName": "Générique", "form": "Comprimé", "strength": "10 mg", "dosage": "1 comprimé", "frequency": "1 fois/jour", "route": "Orale", "duration": "30 jours", "quantity": 30, "quantityDispensed": 10, "quantityRemaining": 20, "instructions": "Après le repas"}], "dispensations": [{"id": "disp-1", "dispenseNumber": "D-1", "pharmacyOrganizationId": "pharmacy-1", "pharmacyName": "Pharmacie", "dispensedAt": "2026-10-02T10:00:00Z", "status": "COMPLETED", "items": [{"id": "di-1", "prescriptionItemId": "rxitem-1", "medicationName": "Médicament", "quantityDispensed": 10}]}]}''',
        )
        as Map<String, dynamic>;
Map<String, dynamic> pageJson() =>
    jsonDecode(
          r'''{"content": [{"id": "rx-1", "prescriptionNumber": "RX-1", "patientId": "patient-1", "consultationId": null, "prescriberId": "doctor-1", "prescriberName": "Médecin", "organizationId": "org-1", "organizationName": "Clinique", "prescribedAt": "2026-10-02T10:00:00Z", "expiresAt": null, "status": "PARTIALLY_DISPENSED", "expired": false}], "page": {"number": 0, "size": 20, "totalElements": 1, "totalPages": 1, "first": true, "last": true}}''',
        )
        as Map<String, dynamic>;
