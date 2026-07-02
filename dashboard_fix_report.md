# Rapport de Résolution : Écran de Tableau de Bord Gris

Nous avons identifié et résolu le problème empêchant l'affichage du tableau de bord. L'écran était entièrement gris en raison d'une exception non gérée lors du rendu.

---

## 🔍 Origine de la panne (Pourquoi l'écran était gris)

Dans Flutter, un écran gris (ou rouge en mode debug) apparaît lorsqu'une erreur survient dans la méthode `build` d'un widget. 

Dans notre cas, `lib/screens/dashboard_screen.dart` utilise le package `intl` pour formater les dates en français (`'fr_FR'`) via `DateFormat` :
- `final formatter = DateFormat('dd MMM', 'fr_FR');` (Ligne 173)
- `final formatter = DateFormat('MMM yyyy', 'fr_FR');` (Ligne 178)

**Le problème :** La locale française (`'fr_FR'`) n'était pas initialisée au démarrage de l'application. Cela levait l'exception suivante :
> `LocaleDataException: Locale data has not been initialized, call initializeDateFormatting(<locale>).`

---

## 🛠️ Actions et Corrections réalisées

### 1. Initialisation de la locale `fr_FR`
Nous avons importé `date_symbol_data_local.dart` et appelé `initializeDateFormatting('fr_FR', null)` dans la fonction `main()` de `lib/main.dart` avant de lancer l'application :
```dart
// Initialisation de la locale fr_FR pour Intl
await initializeDateFormatting('fr_FR', null);
```

### 2. Correction d'un bug de cycle de vie (`setState` pendant le build)
Durant l'analyse, un autre bug a été détecté dans `lib/screens/scan_screen.dart` : la méthode `initState` appelait directement `widget.onScanTypeChanged` qui déclenchait un `setState` sur le widget parent pendant sa construction.
Nous l'avons encapsulée dans un callback post-frame pour respecter le cycle de vie de Flutter :
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  widget.onScanTypeChanged(_isBarcodeMode ? 'barcode' : 'ticket');
});
```

### 3. Mise à jour des tests
- Création d'un test dédié `test/dashboard_screen_test.dart` pour s'assurer que le tableau de bord s'affiche correctement sans crasher.
- Correction de `test/widget_test.dart` pour y configurer Hive et la locale `fr_FR` afin d'éviter les crashs dans les tests unitaires.

> [!NOTE]
> Tous les tests de l'application passent désormais avec succès (`All tests passed!`).

---

## 📊 Ce qui est censé s'afficher sur le Tableau de Bord

Une fois réparé et alimenté par des données de scans, voici les sections visibles à l'écran :

### 1. Si aucune donnée n'a été scannée (`_EmptyDashboardState`)
Un écran épuré avec un logo analytique indiquant **"Aucune donnée"** et vous invitant à réaliser vos premiers scans de produits ou de tickets.

### 2. Si des sessions de scan existent
L'écran affiche une interface sombre très moderne (Style *Neon* / *Glassmorphism*) contenant :

* **Statistiques Globales** : Nombre de scans, total d'articles, montant cumulé (€) et prix moyen par produit.
* **Répartition Nutri-Score** : Barres horizontales de couleur (Vert A à Rouge E) avec le pourcentage d'articles dans chaque catégorie.
* **Évolution dans le temps** : Graphique d'activité de vos dépenses (par semaine et par mois).
* **Totaux par période** : Cartes affichant le total dépensé sur les 7 derniers jours et les 30 derniers jours.
* **Derniers scans** : Liste des 3 derniers scans avec icône (code-barres/ticket), enseigne du magasin, date relative, nombre d'articles et total en euros.
