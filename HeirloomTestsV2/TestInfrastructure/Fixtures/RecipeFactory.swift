//
//  RecipeFactory.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
@testable import Heirloom

/// Factory for creating Recipe test fixtures
/// Supports all 7 languages with realistic, localized data
enum RecipeFactory {

    // MARK: - Basic Recipe Creation

    static func create(
        id: UUID = UUID(),
        title: String = "Test Recipe",
        servings: String = "4",
        prepTime: String = "15 min",
        cookTime: String = "30 min",
        ingredients: [Ingredient]? = nil,
        instructions: [String]? = nil,
        sourceLanguage: String? = nil,
        wasTranslated: Bool = false
    ) -> Recipe {
        return Recipe(
            id: id,
            title: title,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            totalTime: "45 min",
            ingredients: ingredients ?? [IngredientFactory.create()],
            instructions: instructions ?? ["Step 1: Prepare ingredients", "Step 2: Cook", "Step 3: Serve"],
            dateAdded: Date(),
            lastModified: Date(),
            sourceLanguage: sourceLanguage,
            wasTranslated: wasTranslated
        )
    }

    // MARK: - English Recipes

    static func createEnglish(title: String = "Classic Chocolate Chip Cookies") -> Recipe {
        return create(
            title: title,
            servings: "24 cookies",
            prepTime: "15 min",
            cookTime: "12 min",
            ingredients: [
                IngredientFactory.createEnglish(name: "flour", quantity: 2.25, unit: "cup"),
                IngredientFactory.createEnglish(name: "butter, softened", quantity: 1, unit: "cup"),
                IngredientFactory.createEnglish(name: "sugar", quantity: 0.75, unit: "cup"),
                IngredientFactory.createEnglish(name: "eggs", quantity: 2, unit: nil),
                IngredientFactory.createEnglish(name: "vanilla extract", quantity: 2, unit: "tsp"),
                IngredientFactory.createEnglish(name: "baking soda", quantity: 1, unit: "tsp"),
                IngredientFactory.createEnglish(name: "salt", quantity: 1, unit: "tsp"),
                IngredientFactory.createEnglish(name: "chocolate chips", quantity: 2, unit: "cup")
            ],
            instructions: [
                "Preheat oven to 375°F (190°C)",
                "Mix butter and sugars until creamy",
                "Beat in eggs and vanilla",
                "Combine flour, baking soda, and salt in separate bowl",
                "Gradually add dry ingredients to butter mixture",
                "Stir in chocolate chips",
                "Drop rounded tablespoons onto ungreased cookie sheets",
                "Bake 9-11 minutes or until golden brown"
            ],
            sourceLanguage: "en",
            wasTranslated: false
        )
    }

    // MARK: - French Recipes

    static func createFrench(title: String = "Tarte aux Pommes") -> Recipe {
        return create(
            title: title,
            servings: "8 parts",
            prepTime: "20 min",
            cookTime: "45 min",
            ingredients: [
                IngredientFactory.createFrench(name: "pommes", quantity: 6, unit: nil),
                IngredientFactory.createFrench(name: "farine", quantity: 250, unit: "g"),
                IngredientFactory.createFrench(name: "beurre", quantity: 125, unit: "g"),
                IngredientFactory.createFrench(name: "sucre", quantity: 100, unit: "g"),
                IngredientFactory.createFrench(name: "œufs", quantity: 2, unit: nil)
            ],
            instructions: [
                "Préchauffer le four à 180°C",
                "Préparer la pâte avec la farine et le beurre",
                "Éplucher et couper les pommes en tranches",
                "Disposer les pommes sur la pâte",
                "Saupoudrer de sucre",
                "Cuire 45 minutes"
            ],
            sourceLanguage: "fr",
            wasTranslated: true
        )
    }

    // MARK: - Japanese Recipes

    static func createJapanese(title: String = "親子丼") -> Recipe {
        return create(
            title: title,
            servings: "2人分",
            prepTime: "10分",
            cookTime: "15分",
            ingredients: [
                IngredientFactory.createJapanese(name: "鶏もも肉", quantity: 200, unit: "g"),
                IngredientFactory.createJapanese(name: "玉ねぎ", quantity: 1, unit: "個"),
                IngredientFactory.createJapanese(name: "卵", quantity: 3, unit: "個"),
                IngredientFactory.createJapanese(name: "だし汁", quantity: 1, unit: "カップ"),
                IngredientFactory.createJapanese(name: "醤油", quantity: 2, unit: "大さじ"),
                IngredientFactory.createJapanese(name: "みりん", quantity: 2, unit: "大さじ"),
                IngredientFactory.createJapanese(name: "砂糖", quantity: 1, unit: "大さじ")
            ],
            instructions: [
                "鶏肉を一口大に切る",
                "玉ねぎを薄切りにする",
                "鍋にだし汁、醤油、みりん、砂糖を入れて煮立てる",
                "鶏肉と玉ねぎを加えて煮る",
                "溶き卵を回し入れる",
                "半熟になったらご飯にのせる"
            ],
            sourceLanguage: "ja",
            wasTranslated: true
        )
    }

    // MARK: - Korean Recipes

    static func createKorean(title: String = "김치찌개") -> Recipe {
        return create(
            title: title,
            servings: "2인분",
            prepTime: "10분",
            cookTime: "20분",
            ingredients: [
                IngredientFactory.createKorean(name: "김치", quantity: 2, unit: "컵"),
                IngredientFactory.createKorean(name: "돼지고기", quantity: 200, unit: "g"),
                IngredientFactory.createKorean(name: "두부", quantity: 1, unit: "모"),
                IngredientFactory.createKorean(name: "대파", quantity: 1, unit: "대"),
                IngredientFactory.createKorean(name: "고춧가루", quantity: 1, unit: "큰술"),
                IngredientFactory.createKorean(name: "물", quantity: 3, unit: "컵")
            ],
            instructions: [
                "돼지고기를 한입 크기로 자른다",
                "김치를 먹기 좋은 크기로 자른다",
                "냄비에 기름을 두르고 돼지고기를 볶는다",
                "김치와 고춧가루를 넣고 함께 볶는다",
                "물을 넣고 끓인다",
                "두부와 대파를 넣고 5분 더 끓인다"
            ],
            sourceLanguage: "ko",
            wasTranslated: true
        )
    }

    // MARK: - Spanish Recipes

    static func createSpanish(title: String = "Paella Valenciana") -> Recipe {
        return create(
            title: title,
            servings: "4 personas",
            prepTime: "20 min",
            cookTime: "40 min",
            ingredients: [
                IngredientFactory.createSpanish(name: "arroz", quantity: 400, unit: "g"),
                IngredientFactory.createSpanish(name: "pollo", quantity: 500, unit: "g"),
                IngredientFactory.createSpanish(name: "judías verdes", quantity: 200, unit: "g"),
                IngredientFactory.createSpanish(name: "tomate", quantity: 2, unit: nil),
                IngredientFactory.createSpanish(name: "pimentón", quantity: 1, unit: "cucharadita"),
                IngredientFactory.createSpanish(name: "azafrán", quantity: 1, unit: "pizca")
            ],
            instructions: [
                "Calentar aceite en la paellera",
                "Dorar el pollo cortado en trozos",
                "Añadir las verduras y sofreír",
                "Incorporar el tomate rallado",
                "Agregar el arroz y remover",
                "Añadir el caldo y el azafrán",
                "Cocinar sin remover durante 20 minutos"
            ],
            sourceLanguage: "es",
            wasTranslated: true
        )
    }

    // MARK: - German Recipes

    static func createGerman(title: String = "Apfelstrudel") -> Recipe {
        return create(
            title: title,
            servings: "8 Portionen",
            prepTime: "30 min",
            cookTime: "45 min",
            ingredients: [
                IngredientFactory.createGerman(name: "Äpfel", quantity: 6, unit: nil),
                IngredientFactory.createGerman(name: "Mehl", quantity: 300, unit: "g"),
                IngredientFactory.createGerman(name: "Butter", quantity: 150, unit: "g"),
                IngredientFactory.createGerman(name: "Zucker", quantity: 100, unit: "g"),
                IngredientFactory.createGerman(name: "Rosinen", quantity: 50, unit: "g"),
                IngredientFactory.createGerman(name: "Zimt", quantity: 2, unit: "TL")
            ],
            instructions: [
                "Backofen auf 180°C vorheizen",
                "Teig aus Mehl und Butter herstellen",
                "Äpfel schälen und in Scheiben schneiden",
                "Äpfel mit Zucker, Zimt und Rosinen mischen",
                "Teig ausrollen und Füllung verteilen",
                "Strudel aufrollen und auf Backblech legen",
                "45 Minuten backen"
            ],
            sourceLanguage: "de",
            wasTranslated: true
        )
    }

    // MARK: - Chinese Recipes

    static func createChinese(title: String = "宫保鸡丁") -> Recipe {
        return create(
            title: title,
            servings: "2人份",
            prepTime: "15分钟",
            cookTime: "10分钟",
            ingredients: [
                IngredientFactory.createChinese(name: "鸡胸肉", quantity: 300, unit: "克"),
                IngredientFactory.createChinese(name: "花生", quantity: 100, unit: "克"),
                IngredientFactory.createChinese(name: "干辣椒", quantity: 10, unit: "个"),
                IngredientFactory.createChinese(name: "酱油", quantity: 2, unit: "大勺"),
                IngredientFactory.createChinese(name: "糖", quantity: 1, unit: "大勺"),
                IngredientFactory.createChinese(name: "醋", quantity: 1, unit: "大勺")
            ],
            instructions: [
                "鸡肉切成小块",
                "用酱油、糖、醋调成酱汁",
                "热油爆香干辣椒",
                "加入鸡肉翻炒",
                "倒入酱汁",
                "加入花生翻炒均匀"
            ],
            sourceLanguage: "zh",
            wasTranslated: true
        )
    }

    // MARK: - Helper Methods

    /// Create a recipe with specific number of ingredients
    static func createWithIngredientCount(_ count: Int, language: String = "en") -> Recipe {
        let ingredients = (0..<count).map { index in
            IngredientFactory.create(
                name: "Ingredient \(index + 1)",
                quantity: Double.random(in: 1...5),
                unit: ["cup", "tbsp", "tsp", "g", "oz"].randomElement()!
            )
        }

        return create(
            title: "Recipe with \(count) Ingredients",
            ingredients: ingredients,
            sourceLanguage: language
        )
    }

    /// Create a minimal valid recipe
    static func createMinimal() -> Recipe {
        return create(
            title: "Minimal Recipe",
            ingredients: [IngredientFactory.create()],
            instructions: ["Step 1"]
        )
    }

    /// Create a recipe for scaling tests
    static func createForScaling(servings: Int = 4) -> Recipe {
        return create(
            servings: "\(servings)",
            ingredients: [
                IngredientFactory.create(name: "flour", quantity: 2.0, unit: "cup"),
                IngredientFactory.create(name: "sugar", quantity: 1.0, unit: "cup"),
                IngredientFactory.create(name: "eggs", quantity: 2.0, unit: nil),
                IngredientFactory.create(name: "salt", quantity: 0.5, unit: "tsp")
            ]
        )
    }
}
