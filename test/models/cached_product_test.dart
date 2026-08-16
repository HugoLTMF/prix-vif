import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/models/hive_models.dart';

void main() {
  group('CachedProduct Serialization Tests', () {
    test('toMap and fromMap should preserve new Open Food Facts fields', () {
      final product = CachedProduct(
        ean: '3017670010471',
        productName: 'Nutella 400g',
        brands: 'Ferrero',
        nutriscoreGrade: 'e',
        imageUrl: 'https://images.openfoodfacts.org/images/products/301/767/001/0471/front_fr.395.400.jpg',
        categories: ['Pâtes à tartiner', 'Produits sucrés'],
        cachedAt: DateTime(2026, 7, 18, 12, 0, 0),
        ecoscoreGrade: 'd',
        novaGroup: 4,
        ingredients: 'Sucre, huile de palme, noisettes 13%, lait écrémé en poudre 8.7%, cacao maigre 7.4%, émulsifiants : lécithines [soja], vanilline.',
        allergens: ['Lait', 'Noisettes', 'Soja'],
        nutrientLevels: {
          'fat': 'high',
          'saturated-fat': 'high',
          'sugars': 'high',
          'salt': 'low',
        },
        nutriments: {
          'energy-kcal_100g': 539.0,
          'fat_100g': 30.9,
          'saturated-fat_100g': 10.6,
          'carbohydrates_100g': 57.5,
          'sugars_100g': 56.3,
          'proteins_100g': 6.3,
          'salt_100g': 0.107,
        },
      );

      final map = product.toMap();
      
      expect(map['ean'], '3017670010471');
      expect(map['productName'], 'Nutella 400g');
      expect(map['brands'], 'Ferrero');
      expect(map['nutriscoreGrade'], 'e');
      expect(map['ecoscoreGrade'], 'd');
      expect(map['novaGroup'], 4);
      expect(map['ingredients'], contains('Sucre'));
      expect(map['allergens'], contains('Lait'));
      expect(map['nutrientLevels']['fat'], 'high');
      expect(map['nutriments']['sugars_100g'], 56.3);

      final deserialized = CachedProduct.fromMap(map);

      expect(deserialized.ean, product.ean);
      expect(deserialized.productName, product.productName);
      expect(deserialized.brands, product.brands);
      expect(deserialized.nutriscoreGrade, product.nutriscoreGrade);
      expect(deserialized.imageUrl, product.imageUrl);
      expect(deserialized.categories, product.categories);
      expect(deserialized.cachedAt, product.cachedAt);
      expect(deserialized.ecoscoreGrade, product.ecoscoreGrade);
      expect(deserialized.novaGroup, product.novaGroup);
      expect(deserialized.ingredients, product.ingredients);
      expect(deserialized.allergens, product.allergens);
      expect(deserialized.nutrientLevels?['fat'], 'high');
      expect(deserialized.nutriments?['sugars_100g'], 56.3);
    });

    test('fromMap should handle missing optional fields safely (retrocompatibility)', () {
      final legacyMap = {
        'ean': '1234567890123',
        'productName': 'Lait demi-écrémé',
        'brands': 'Lactel',
        'nutriscoreGrade': 'b',
        'imageUrl': 'http://example.com/lait.png',
        'categories': ['Produits laitiers', 'Laits'],
        'cachedAt': DateTime(2026, 1, 1).toIso8601String(),
      };

      final product = CachedProduct.fromMap(legacyMap);

      expect(product.ean, '1234567890123');
      expect(product.productName, 'Lait demi-écrémé');
      expect(product.ecoscoreGrade, isNull);
      expect(product.novaGroup, isNull);
      expect(product.ingredients, isNull);
      expect(product.allergens, isNull);
      expect(product.nutrientLevels, isNull);
      expect(product.nutriments, isNull);
    });
  });
}
