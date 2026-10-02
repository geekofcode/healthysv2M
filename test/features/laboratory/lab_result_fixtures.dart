import 'dart:convert';

Map<String, dynamic> summaryJson() =>
    jsonDecode(
          r'''{"id": "result-1", "resultNumber": "LR-1", "labOrderId": "order-1", "orderNumber": "LO-1", "patientId": "patient-1", "laboratoryOrganizationId": "org-1", "laboratoryName": "Labo", "orderedAt": "2026-10-02T10:00:00Z", "performedAt": "2026-10-02T10:00:00Z", "validatedAt": "2026-10-02T10:00:00Z", "status": "FINAL"}''',
        )
        as Map<String, dynamic>;
Map<String, dynamic> detailJson() =>
    jsonDecode(
          r'''{"result": {"id": "result-1", "resultNumber": "LR-1", "labOrderId": "order-1", "orderNumber": "LO-1", "patientId": "patient-1", "laboratoryOrganizationId": "org-1", "laboratoryName": "Labo", "orderedAt": "2026-10-02T10:00:00Z", "performedAt": "2026-10-02T10:00:00Z", "validatedAt": "2026-10-02T10:00:00Z", "status": "FINAL"}, "items": [{"id": "item-1", "labOrderItemId": "exam-1", "examCode": "GLU", "examName": "Glycémie", "parameterCatalogId": null, "parameter": "Glucose", "value": "5.20", "unit": "mmol/L", "referenceMin": 3.9, "referenceMax": 6.1, "interpretation": null, "abnormalFlag": null}]}''',
        )
        as Map<String, dynamic>;
Map<String, dynamic> pageJson() =>
    jsonDecode(
          r'''{"content": [{"id": "result-1", "resultNumber": "LR-1", "labOrderId": "order-1", "orderNumber": "LO-1", "patientId": "patient-1", "laboratoryOrganizationId": "org-1", "laboratoryName": "Labo", "orderedAt": "2026-10-02T10:00:00Z", "performedAt": "2026-10-02T10:00:00Z", "validatedAt": "2026-10-02T10:00:00Z", "status": "FINAL"}], "page": {"number": 0, "size": 20, "totalElements": 1, "totalPages": 1, "first": true, "last": true}}''',
        )
        as Map<String, dynamic>;
