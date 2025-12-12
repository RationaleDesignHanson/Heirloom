// prototypes/ShoppingListDemo.tsx
// Interactive prototype: Smart shopping list aggregation

'use client'

import { useState } from 'react'

interface Recipe {
  id: string
  name: string
  ingredients: string[]
  selected: boolean
}

const sampleRecipes: Recipe[] = [
  {
    id: 'lasagna',
    name: 'Grandma\'s Lasagna',
    ingredients: [
      '2 cloves garlic',
      '1 lb ground beef',
      '2 cups ricotta cheese',
      '2 cups mozzarella cheese',
      '1 can tomato sauce',
      '1 box lasagna noodles',
    ],
    selected: false,
  },
  {
    id: 'salad',
    name: 'Caesar Salad',
    ingredients: [
      '1 head romaine lettuce',
      '2 cloves garlic',
      '1/2 cup parmesan cheese',
      '1/4 cup olive oil',
      '2 tablespoons lemon juice',
      'Caesar dressing',
    ],
    selected: false,
  },
  {
    id: 'bread',
    name: 'Garlic Bread',
    ingredients: [
      '1 loaf French bread',
      '4 cloves garlic',
      '1/2 cup butter',
      '1/4 cup parsley',
      '1/4 cup parmesan cheese',
    ],
    selected: false,
  },
]

interface AggregatedIngredient {
  name: string
  category: string
  recipes: string[]
  checked: boolean
}

export default function ShoppingListDemo() {
  const [recipes, setRecipes] = useState(sampleRecipes)
  const [showList, setShowList] = useState(false)

  const toggleRecipe = (id: string) => {
    setRecipes(recipes.map((r) => (r.id === id ? { ...r, selected: !r.selected } : r)))
    setShowList(false) // Reset list when recipes change
  }

  const generateShoppingList = () => {
    setShowList(true)
  }

  // Aggregate ingredients from selected recipes
  const aggregatedList = (): AggregatedIngredient[] => {
    const selected = recipes.filter((r) => r.selected)
    const ingredientMap = new Map<string, AggregatedIngredient>()

    selected.forEach((recipe) => {
      recipe.ingredients.forEach((ingredient) => {
        // Simple keyword matching for aggregation
        const normalized = ingredient.toLowerCase()

        // Extract key ingredient name (simplified)
        let key = normalized
        if (normalized.includes('garlic')) key = 'garlic'
        else if (normalized.includes('cheese') && normalized.includes('parmesan'))
          key = 'parmesan cheese'
        else if (normalized.includes('cheese') && normalized.includes('ricotta'))
          key = 'ricotta cheese'
        else if (normalized.includes('cheese') && normalized.includes('mozzarella'))
          key = 'mozzarella cheese'

        if (ingredientMap.has(key)) {
          const existing = ingredientMap.get(key)!
          existing.recipes.push(recipe.name)
        } else {
          // Categorize
          let category = 'Other'
          if (normalized.includes('lettuce') || normalized.includes('parsley')) category = 'Produce'
          else if (normalized.includes('garlic')) category = 'Produce'
          else if (normalized.includes('cheese') || normalized.includes('butter'))
            category = 'Dairy'
          else if (normalized.includes('beef')) category = 'Meat'
          else if (
            normalized.includes('noodles') ||
            normalized.includes('bread') ||
            normalized.includes('sauce')
          )
            category = 'Pantry'

          ingredientMap.set(key, {
            name: ingredient,
            category,
            recipes: [recipe.name],
            checked: false,
          })
        }
      })
    })

    // Group by category
    const grouped = Array.from(ingredientMap.values())
    grouped.sort((a, b) => {
      if (a.category !== b.category) return a.category.localeCompare(b.category)
      return a.name.localeCompare(b.name)
    })

    return grouped
  }

  const list = showList ? aggregatedList() : []
  const categories = [...new Set(list.map((i) => i.category))]

  return (
    <div className="mx-auto max-w-5xl">
      <div className="grid gap-8 lg:grid-cols-2">
        {/* Recipe Selection */}
        <div>
          <div className="mb-4 text-sm font-semibold text-gray-500">STEP 1: SELECT RECIPES</div>

          <div className="space-y-3">
            {recipes.map((recipe) => (
              <div
                key={recipe.id}
                className={`rounded-xl border-2 p-4 transition-all cursor-pointer ${
                  recipe.selected
                    ? 'border-[#E85D4D] bg-[#FBF8F3]'
                    : 'border-gray-200 bg-white hover:border-gray-300'
                }`}
                onClick={() => toggleRecipe(recipe.id)}
              >
                <div className="flex items-start gap-3">
                  <div className="mt-1">
                    {recipe.selected ? (
                      <div className="h-6 w-6 rounded-full bg-[#E85D4D] flex items-center justify-center text-white">
                        ✓
                      </div>
                    ) : (
                      <div className="h-6 w-6 rounded-full border-2 border-gray-300"></div>
                    )}
                  </div>

                  <div className="flex-1">
                    <div className="font-semibold text-[#2D2D2D]">{recipe.name}</div>
                    <div className="mt-1 text-sm text-gray-600">
                      {recipe.ingredients.length} ingredients
                    </div>

                    {recipe.selected && (
                      <div className="mt-2 space-y-1 text-xs text-gray-500">
                        {recipe.ingredients.slice(0, 3).map((ing, i) => (
                          <div key={i}>• {ing}</div>
                        ))}
                        {recipe.ingredients.length > 3 && (
                          <div className="text-gray-400">
                            + {recipe.ingredients.length - 3} more
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>

          <button
            onClick={generateShoppingList}
            disabled={recipes.filter((r) => r.selected).length === 0}
            className="mt-6 w-full rounded-lg bg-[#E85D4D] px-6 py-3 font-semibold text-white transition-all hover:bg-[#d54d3d] disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            {showList ? 'Update' : 'Generate'} Shopping List
          </button>
        </div>

        {/* Shopping List Output */}
        <div>
          <div className="mb-4 text-sm font-semibold text-gray-500">STEP 2: SHOPPING LIST</div>

          {!showList ? (
            <div className="flex h-full min-h-[300px] items-center justify-center rounded-xl border-2 border-dashed border-gray-300 bg-gray-50">
              <div className="text-center text-gray-400">
                <div className="mb-2 text-4xl">🛒</div>
                <div className="text-sm">Select recipes to generate list</div>
              </div>
            </div>
          ) : (
            <div className="rounded-xl border-2 border-gray-200 bg-white">
              {/* Header */}
              <div className="border-b border-gray-200 p-4">
                <div className="flex items-center justify-between">
                  <div className="font-semibold text-[#2D2D2D]">
                    {list.length} ingredients from {recipes.filter((r) => r.selected).length} recipes
                  </div>
                  <button className="text-sm font-semibold text-[#E85D4D] hover:underline">
                    Export to Reminders →
                  </button>
                </div>
              </div>

              {/* Categories */}
              <div className="max-h-[500px] overflow-y-auto">
                {categories.map((category) => (
                  <div key={category} className="border-b border-gray-100 last:border-b-0">
                    <div className="bg-gray-50 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-gray-600">
                      {category}
                    </div>
                    <div className="divide-y divide-gray-100">
                      {list
                        .filter((item) => item.category === category)
                        .map((item, i) => (
                          <div key={i} className="px-4 py-3 hover:bg-gray-50">
                            <div className="flex items-start gap-3">
                              <div className="mt-1">
                                <div className="h-5 w-5 rounded border-2 border-gray-300"></div>
                              </div>
                              <div className="flex-1">
                                <div className="text-sm text-[#2D2D2D]">{item.name}</div>
                                {item.recipes.length > 1 && (
                                  <div className="mt-1 text-xs text-gray-500">
                                    From {item.recipes.length} recipes:{' '}
                                    {item.recipes.join(', ')}
                                  </div>
                                )}
                              </div>
                            </div>
                          </div>
                        ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Instructions */}
      <div className="mt-8 rounded-xl bg-[#FBF8F3] p-6">
        <h4 className="mb-3 font-semibold text-[#2D2D2D]">How it works:</h4>
        <ul className="space-y-2 text-sm text-gray-700">
          <li>• Select 2-3 recipes on the left</li>
          <li>• Click "Generate Shopping List"</li>
          <li>• Notice how "garlic" from all 3 recipes is intelligently combined</li>
          <li>• Ingredients are automatically organized by grocery aisle (Produce, Dairy, Meat, Pantry)</li>
          <li>• In the real app, you can check off items and export directly to iOS Reminders</li>
        </ul>
      </div>
    </div>
  )
}
