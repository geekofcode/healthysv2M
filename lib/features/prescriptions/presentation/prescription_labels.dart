String prescriptionStatus(String status, bool fr) =>
    switch (status.toUpperCase()) {
      'ACTIVE' => fr ? 'Active' : 'Active',
      'ISSUED' => fr ? 'Émise' : 'Issued',
      'PARTIALLY_DISPENSED' =>
        fr ? 'Partiellement dispensée' : 'Partially dispensed',
      'DISPENSED' || 'FULLY_DISPENSED' => fr ? 'Dispensée' : 'Dispensed',
      'CANCELLED' => fr ? 'Annulée' : 'Cancelled',
      'EXPIRED' => fr ? 'Expirée' : 'Expired',
      'COMPLETED' => fr ? 'Terminée' : 'Completed',
      _ => fr ? 'Statut non renseigné' : 'Status not provided',
    };
