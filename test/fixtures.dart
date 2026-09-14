/// Réponses Youprice réelles (anonymisées) partagées entre les tests.
library;

const realConso = {
  'categories': [
    {
      'libelle': 'En France métropolitaine',
      'sousCategories': [
        {
          'libelle': 'Internet mobile',
          'detais': [
            {
              'libelle': 'En  France',
              'valeur': '4,6 GO',
              'valeurRef': "50 GO Ajustable jusqu'à 50 GO",
            },
          ],
        },
        {
          'libelle': 'Appels',
          'detais': [
            {
              'libelle': "Heures d'appel en France",
              'valeur': '00:00:48',
              'valeurRef': null,
            },
          ],
        },
      ],
    },
    {
      'libelle': "Depuis l'international",
      'sousCategories': [
        {
          'libelle': 'Internet mobile',
          'detais': [
            {'libelle': 'Depuis  Zone1', 'valeur': '1,4 GO', 'valeurRef': null},
          ],
        },
      ],
    },
  ],
};

const realInvoice = {
  'id': 13540411,
  'invoiceName': 'Facture mensuelle',
  'invoiceDate': '2026-08-31T00:00:00',
  'montantTTC': 4.99,
  'invoiceStatus': 'Payé',
  'montantRestant': 0.0,
};

const realLine = {
  'etatLigne': 'Active',
  'ypProductName': '50Go',
  'operateur': 'SFR',
  'typeSim': 'Sim',
  'isOption5G': false,
};

const realCustomer = {
  'result': {'firstName': 'Jean', 'lastName': 'Dupont'},
};

const phoneNumber = '0612345678';
