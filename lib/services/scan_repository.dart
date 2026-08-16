import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';
import '../models/hive_models.dart';

// ===================================================
// Étape 3c — Couche Repository
// ===================================================
// ScanRepository : interface unique pour toutes les
// opérations de persistance (CRUD scans, articles, cache OFF)
// ===================================================

class ScanRepository {
  static const String _scansBoxName = 'scans';
  static const String _articlesBoxName = 'articles';
  static const String _productsBoxName = 'products_cache';
  static const String _mistralExtractionsBoxName = 'mistral_extractions';
  static const String _pendingOfflineScansBoxName = 'pending_offline_scans';
  static const String _settingsBoxName = 'settings';

  late Box<Map> _scansBox;
  late Box<Map> _articlesBox;
  late Box<Map> _productsBox;
  late Box<Map> _mistralExtractionsBox;
  late Box<Map> _pendingOfflineScansBox;
  late Box<Map> _settingsBox;

  bool _isInitialized = false;

  /// Initialise Hive et ouvre les boxes
  Future<void> init() async {
    if (_isInitialized) return;

    _scansBox = await Hive.openBox<Map>(_scansBoxName);
    _articlesBox = await Hive.openBox<Map>(_articlesBoxName);
    _productsBox = await Hive.openBox<Map>(_productsBoxName);
    _mistralExtractionsBox = await Hive.openBox<Map>(_mistralExtractionsBoxName);
    _pendingOfflineScansBox = await Hive.openBox<Map>(_pendingOfflineScansBoxName);
    _settingsBox = await Hive.openBox<Map>(_settingsBoxName);

    _isInitialized = true;
  }

  // ==========================================
  // Paramètres (Settings)
  // ==========================================

  /// Sauvegarde la clé API Mistral
  Future<void> saveMistralApiKey(String key) async {
    await _settingsBox.put('mistral_api_key', {'key': key});
  }

  /// Récupère la clé API Mistral
  String? getMistralApiKey() {
    final data = _settingsBox.get('mistral_api_key');
    if (data == null) return null;
    return data['key'] as String?;
  }

  // ==========================================
  // CRUD — Scans (sessions)
  // ==========================================

  /// Sauvegarde une session complète (scan + articles)
  Future<void> saveScan(ScanSession session) async {
    final storedScan = StoredScan(
      id: session.id,
      date: session.date,
      endDate: session.endDate,
      type: session.type,
      storeName: session.storeName,
      totalAmount: session.totalAmount,
    );

    // Persister le scan
    await _scansBox.put(session.id, storedScan.toMap());

    // Persister chaque article du scan
    for (final item in session.items) {
      await saveArticle(item, session.id);
    }
  }

  /// Récupère toutes les sessions, triées par date décroissante
  Future<List<ScanSession>> getAllScans() async {
    final scans = <ScanSession>[];

    for (final key in _scansBox.keys) {
      final scanMap = _scansBox.get(key);
      if (scanMap == null) continue;

      final storedScan = StoredScan.fromMap(scanMap);

      // Récupérer les articles associés
      final articles = await getArticlesForScan(storedScan.id);

      scans.add(ScanSession(
        id: storedScan.id,
        items: articles,
        date: storedScan.date,
        endDate: storedScan.endDate,
        storeName: storedScan.storeName,
        type: storedScan.type,
      ));
    }

    // Tri par date décroissante
    scans.sort((a, b) => b.date.compareTo(a.date));
    return scans;
  }

  /// Supprime une session et ses articles associés
  Future<void> deleteScan(String scanId) async {
    await _scansBox.delete(scanId);

    // Supprimer les articles associés
    final keysToDelete = <dynamic>[];
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap != null && articleMap['scanId'] == scanId) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      await _articlesBox.delete(key);
    }
  }

  /// Supprime toutes les sessions et tous les articles
  Future<void> clearAllScans() async {
    await _scansBox.clear();
    await _articlesBox.clear();
  }

  // ==========================================
  // CRUD — Articles
  // ==========================================

  /// Sauvegarde un article lié à un scan
  Future<void> saveArticle(ScannedItem item, String scanId) async {
    final storedArticle = StoredArticle(
      id: item.id,
      name: item.name,
      brand: item.brand,
      price: item.price,
      currency: item.currency,
      quantity: item.quantity,
      unit: item.unit,
      scanDate: item.scanDate,
      imageUrl: item.imageUrl,
      barcode: item.barcode,
      storeName: item.storeName,
      nutriscore: item.nutriscore,
      categories: item.categories,
      scanId: scanId,
    );

    await _articlesBox.put(item.id, storedArticle.toMap());
  }

  /// Récupère les articles d'un scan donné
  Future<List<ScannedItem>> getArticlesForScan(String scanId) async {
    final items = <ScannedItem>[];

    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap == null) continue;
      if (articleMap['scanId'] != scanId) continue;

      final stored = StoredArticle.fromMap(articleMap);
      items.add(ScannedItem(
        id: stored.id,
        name: stored.name,
        brand: stored.brand,
        price: stored.price,
        currency: stored.currency,
        quantity: stored.quantity,
        unit: stored.unit,
        scanDate: stored.scanDate,
        imageUrl: stored.imageUrl,
        barcode: stored.barcode,
        storeName: stored.storeName,
        nutriscore: stored.nutriscore,
        categories: stored.categories,
      ));
    }

    return items;
  }

  // ==========================================
  // Cache — Produits OFF
  // ==========================================

  /// Récupère un produit du cache par EAN
  CachedProduct? getCachedProduct(String ean) {
    final map = _productsBox.get(ean);
    if (map == null) return null;
    return CachedProduct.fromMap(map);
  }

  /// Met en cache un produit OFF (clé = EAN)
  Future<void> cacheProduct(CachedProduct product) async {
    await _productsBox.put(product.ean, product.toMap());
  }

  /// Vérifie si un produit est en cache
  bool hasProductInCache(String ean) {
    return _productsBox.containsKey(ean);
  }

  /// Nombre total de produits en cache
  int get cachedProductCount => _productsBox.length;

  /// Nombre total de scans persistés
  int get scanCount => _scansBox.length;

  /// Nombre total d'articles persistés
  int get articleCount => _articlesBox.length;

  // ==========================================
  // Extractions Mistral — Pour rejouer sans coût
  // ==========================================

  /// Sauvegarde une extraction Mistral brute
  Future<void> saveMistralExtraction(StoredMistralExtraction extraction) async {
    await _mistralExtractionsBox.put(extraction.id, extraction.toMap());
  }

  /// Récupère une extraction Mistral par ID
  StoredMistralExtraction? getMistralExtraction(String id) {
    final map = _mistralExtractionsBox.get(id);
    if (map == null) return null;
    return StoredMistralExtraction.fromMap(map);
  }

  /// Récupère toutes les extractions Mistral pour un scan donné
  List<StoredMistralExtraction> getMistralExtractionsForScan(String scanId) {
    final extractions = <StoredMistralExtraction>[];
    for (final key in _mistralExtractionsBox.keys) {
      final map = _mistralExtractionsBox.get(key);
      if (map == null) continue;
      final extraction = StoredMistralExtraction.fromMap(map);
      if (extraction.scanId == scanId) {
        extractions.add(extraction);
      }
    }
    return extractions;
  }

  /// Supprime une extraction Mistral
  Future<void> deleteMistralExtraction(String id) async {
    await _mistralExtractionsBox.delete(id);
  }

  /// Supprime toutes les extractions Mistral pour un scan
  Future<void> deleteMistralExtractionsForScan(String scanId) async {
    final extractions = getMistralExtractionsForScan(scanId);
    for (final extraction in extractions) {
      await deleteMistralExtraction(extraction.id);
    }
  }

  /// Nombre total d'extractions Mistral persistées
  int get mistralExtractionCount => _mistralExtractionsBox.length;

  // ==========================================
  // Scans en attente — Mode hors-ligne (Étape 5c)
  // ==========================================

  /// Sauvegarde un scan en attente de traitement (hors-ligne)
  Future<void> savePendingOfflineScan(PendingOfflineScan scan) async {
    await _pendingOfflineScansBox.put(scan.id, scan.toMap());
  }

  /// Récupère tous les scans en attente
  List<PendingOfflineScan> getAllPendingOfflineScans() {
    final pending = <PendingOfflineScan>[];
    for (final key in _pendingOfflineScansBox.keys) {
      final map = _pendingOfflineScansBox.get(key);
      if (map != null) {
        pending.add(PendingOfflineScan.fromMap(map));
      }
    }
    // Tri par date croissante (FIFO)
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pending;
  }

  /// Récupère un scan en attente par ID
  PendingOfflineScan? getPendingOfflineScan(String id) {
    final map = _pendingOfflineScansBox.get(id);
    if (map == null) return null;
    return PendingOfflineScan.fromMap(map);
  }

  /// Supprime un scan en attente
  Future<void> deletePendingOfflineScan(String id) async {
    await _pendingOfflineScansBox.delete(id);
  }

  /// Supprime tous les scans en attente
  Future<void> clearAllPendingOfflineScans() async {
    await _pendingOfflineScansBox.clear();
  }

  /// Vérifie s'il y a des scans en attente
  bool hasPendingOfflineScans() {
    return _pendingOfflineScansBox.isNotEmpty;
  }

  /// Nombre de scans en attente
  int get pendingOfflineScanCount => _pendingOfflineScansBox.length;

  // ==========================================
  // Analyse par produit — Étape 6
  // ==========================================

  /// Récupère tous les articles avec leurs informations complètes
  List<StoredArticle> getAllStoredArticles() {
    final allArticles = <StoredArticle>[];
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap != null) {
        allArticles.add(StoredArticle.fromMap(articleMap));
      }
    }
    return allArticles;
  }

  /// Récupère tous les articles par nom de produit
  List<StoredArticle> getArticlesByProductName(String productName) {
    final allArticles = getAllStoredArticles();
    return allArticles
        .where((article) => 
            article.name.toLowerCase().contains(productName.toLowerCase()))
        .toList();
  }

  /// Récupère tous les articles par code-barres (EAN)
  List<StoredArticle> getArticlesByBarcode(String barcode) {
    final allArticles = getAllStoredArticles();
    return allArticles
        .where((article) => article.barcode == barcode)
        .toList();
  }

  /// Récupère tous les articles par nom de magasin
  List<StoredArticle> getArticlesByStore(String storeName) {
    final allArticles = getAllStoredArticles();
    return allArticles
        .where((article) => article.storeName == storeName)
        .toList();
  }

  /// Récupère l'historique des prix d'un produit dans un magasin spécifique
  /// Retourne une liste de PricePoint triée par date
  List<Map<String, dynamic>> getPriceHistory(String productId, String storeName) {
    final history = <Map<String, dynamic>>[];
    
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap == null) continue;
      
      // On identifie le produit par son ID ou son barcode
      final articleProductId = articleMap['id'] as String?;
      final articleBarcode = articleMap['barcode'] as String?;
      final articleStore = articleMap['storeName'] as String?;
      
      // Correspondance par ID ou par barcode (si ID = productId ou barcode = productId)
      final matchesProduct = articleProductId == productId || 
          articleBarcode == productId ||
          (articleMap['name'] as String?) == productId;
      
      if (matchesProduct && articleStore == storeName) {
        history.add({
          'id': key,
          'date': articleMap['scanDate'],
          'price': articleMap['price'],
          'quantity': articleMap['quantity'],
          'unit': articleMap['unit'],
          'name': articleMap['name'],
          'brand': articleMap['brand'],
          'barcode': articleMap['barcode'],
        });
      }
    }
    
    // Tri par date croissante
    history.sort((a, b) => 
        DateTime.parse(a['date'] as String).compareTo(
            DateTime.parse(b['date'] as String)));
    
    return history;
  }

  /// Récupère l'historique des prix d'un produit dans tous les magasins
  /// Retourne une map : storeName to List of PricePoint
  Map<String, List<Map<String, dynamic>>> getPriceHistoryByStore(String productId) {
    final historyByStore = <String, List<Map<String, dynamic>>>{};
    
    for (final key in _articlesBox.keys) {
      final articleMap = _articlesBox.get(key);
      if (articleMap == null) continue;
      
      final articleProductId = articleMap['id'] as String?;
      final articleBarcode = articleMap['barcode'] as String?;
      final articleStore = articleMap['storeName'] as String? ?? 'Inconnu';
      
      // Correspondance par ID, barcode ou nom
      final matchesProduct = articleProductId == productId || 
          articleBarcode == productId ||
          (articleMap['name'] as String?) == productId;
      
      if (matchesProduct) {
        if (!historyByStore.containsKey(articleStore)) {
          historyByStore[articleStore] = [];
        }
        historyByStore[articleStore]!.add({
          'id': key,
          'date': articleMap['scanDate'],
          'price': articleMap['price'],
          'quantity': articleMap['quantity'],
          'unit': articleMap['unit'],
        });
      }
    }
    
    // Tri chaque liste par date
    for (final store in historyByStore.keys) {
      historyByStore[store]!.sort((a, b) => 
          DateTime.parse(a['date'] as String).compareTo(
              DateTime.parse(b['date'] as String)));
    }
    
    return historyByStore;
  }

  /// Récupère tous les produits uniques scannés
  /// Un produit est identifié par son nom + marque + barcode
  List<Map<String, dynamic>> getUniqueProducts() {
    final allArticles = getAllStoredArticles();
    final uniqueProducts = <String, Map<String, dynamic>>{};
    
    for (final article in allArticles) {
      // Clé unique : nom + marque + barcode (ou juste barcode si présent)
      final key = article.barcode ?? '${article.name}_${article.brand}';
      
      if (!uniqueProducts.containsKey(key)) {
        uniqueProducts[key] = {
          'id': article.id,
          'name': article.name,
          'brand': article.brand,
          'barcode': article.barcode,
          'imageUrl': article.imageUrl,
          'nutriscore': article.nutriscore,
          'categories': article.categories,
          'prices': <double>[article.price],
          'scanDates': <DateTime>[article.scanDate],
          'stores': <String>{},
          'scanCount': 1,
          'totalPrice': article.price,
        };
      } else {
        final product = uniqueProducts[key]!;
        product['prices']!.add(article.price);
        product['scanDates']!.add(article.scanDate);
        if (article.storeName != null) {
          (product['stores'] as Set<String>).add(article.storeName!);
        }
        product['scanCount'] = (product['scanCount'] as int) + 1;
        product['totalPrice'] = (product['totalPrice'] as double) + article.price;
      }
    }
    
    // Convertir en liste et ajouter les moyennes
    final result = <Map<String, dynamic>>[];
    for (final product in uniqueProducts.values) {
      final prices = product['prices'] as List<double>;
      final avgPrice = prices.isNotEmpty ? prices.reduce((a, b) => a + b) / prices.length : 0.0;
      final scanDates = product['scanDates'] as List<DateTime>;
      final lastScanDate = scanDates.isNotEmpty 
          ? scanDates.reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now();
      
      result.add({
        'id': product['id'],
        'name': product['name'],
        'brand': product['brand'],
        'barcode': product['barcode'],
        'imageUrl': product['imageUrl'],
        'nutriscore': product['nutriscore'],
        'categories': product['categories'],
        'scanCount': product['scanCount'],
        'averagePrice': avgPrice,
        'lastScanDate': lastScanDate,
        'stores': (product['stores'] as Set<String>).toList(),
      });
    }
    
    // Tri par nom de produit
    result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    return result;
  }

  /// Récupère les produits similaires à un produit donné (même catégorie)
  List<Map<String, dynamic>> getSimilarProducts(String productId, {String? category}) {
    final allArticles = getAllStoredArticles();
    
    // Trouver le produit de référence
    StoredArticle? referenceArticle;
    for (final article in allArticles) {
      if (article.id == productId || article.barcode == productId) {
        referenceArticle = article;
        break;
      }
    }
    
    // Si on a pas trouvé par ID, chercher par nom
    if (referenceArticle == null) {
      for (final article in allArticles) {
        if (article.name == productId) {
          referenceArticle = article;
          break;
        }
      }
    }
    
    if (referenceArticle == null) return [];
    
    // Utiliser la catégorie du produit de référence ou celle fournie
    final targetCategory = category ?? 
        (referenceArticle.categories?.isNotEmpty == true 
            ? referenceArticle.categories!.first
            : null);
    
    // Récupérer tous les articles de la même catégorie ou avec un nom similaire
    final similarProducts = <Map<String, dynamic>>[];
    
    for (final article in allArticles) {
      // Éviter d'inclure le produit de référence lui-même
      if (article.id == referenceArticle.id) continue;
      
      // Vérifier la catégorie
      final hasSameCategory = targetCategory != null && 
          article.categories?.contains(targetCategory) == true;
      
      // Vérifier la similarité du nom (si pas de catégorie)
      final hasSimilarName = targetCategory == null && 
          article.name.toLowerCase().contains(
              referenceArticle.name.toLowerCase().split(' ').first) == true;
      
      if (hasSameCategory || hasSimilarName) {
        similarProducts.add({
          'id': article.id,
          'name': article.name,
          'brand': article.brand,
          'barcode': article.barcode,
          'storeName': article.storeName,
          'price': article.price,
          'scanDate': article.scanDate,
          'nutriscore': article.nutriscore,
          'imageUrl': article.imageUrl,
          'categories': article.categories,
        });
      }
    }
    
    // Tri par prix croissant
    similarProducts.sort((a, b) => 
        (a['price'] as double).compareTo(b['price'] as double));
    
    return similarProducts;
  }

  /// Récupère la comparaison des prix d'un produit entre tous les magasins
  Map<String, dynamic> getStorePriceComparison(String productId) {
    final historyByStore = getPriceHistoryByStore(productId);
    final comparison = <String, dynamic>{};
    
    for (final entry in historyByStore.entries) {
      final storeName = entry.key;
      final pricePoints = entry.value;
      
      if (pricePoints.isNotEmpty) {
        final prices = pricePoints.map((p) => p['price'] as double).toList();
        final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
        final lastPrice = pricePoints.last['price'] as double;
        final lastScanDate = DateTime.parse(pricePoints.last['date'] as String);
        
        comparison[storeName] = {
          'storeName': storeName,
          'averagePrice': avgPrice,
          'lastPrice': lastPrice,
          'lastScanDate': lastScanDate.toIso8601String(),
          'scanCount': pricePoints.length,
        };
      }
    }
    
    return comparison;
  }

  /// Supprime un magasin de tous les articles d'un produit
  /// Met à jour le storeName à null pour tous les articles correspondants
  Future<void> removeStoreFromProduct(String storeName, String productId) async {
    final allArticles = getAllStoredArticles();
    
    for (final article in allArticles) {
      // Identifier l'article par productId (qui peut être id, barcode ou name)
      final matchesProduct = article.id == productId || 
          article.barcode == productId ||
          article.name == productId;
      
      if (matchesProduct && article.storeName == storeName) {
        // Créer une copie modifiée de l'article
        final updatedArticle = StoredArticle(
          id: article.id,
          name: article.name,
          brand: article.brand,
          price: article.price,
          currency: article.currency,
          quantity: article.quantity,
          unit: article.unit,
          scanDate: article.scanDate,
          imageUrl: article.imageUrl,
          barcode: article.barcode,
          storeName: null, // Supprimer le magasin
          nutriscore: article.nutriscore,
          categories: article.categories,
          scanId: article.scanId,
        );
        
        // Sauvegarder l'article modifié
        await _articlesBox.put(article.id, updatedArticle.toMap());
      }
    }
  }

  /// Récupère la liste des noms de magasins uniques pour un produit
  List<String> getStoresForProduct(String productId) {
    final allArticles = getAllStoredArticles();
    final stores = <String>{};
    
    for (final article in allArticles) {
      final matchesProduct = article.id == productId || 
          article.barcode == productId ||
          article.name == productId;
      
      if (matchesProduct && article.storeName != null) {
        stores.add(article.storeName!);
      }
    }
    
    return stores.toList();
  }
}
