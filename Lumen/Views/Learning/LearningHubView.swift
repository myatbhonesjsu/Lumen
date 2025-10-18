//
//  LearningHubView.swift
//  Lumen
//
//  AI Skincare Assistant - Educational Content
//

import SwiftUI

struct LearningHubView: View {
    @State private var selectedCategory = "All"
    @State private var selectedArticle: EducationalContent?

    let categories = ["All", "Basics", "Ingredients", "Routines", "Conditions"]

    let articles: [EducationalContent] = [
        EducationalContent(
            title: "Understanding Your Skin Type",
            category: "Basics",
            content: """
            Knowing your skin type is the foundation of any effective skincare routine.

            **Skin Types:**

            • **Normal**: Balanced, not too oily or dry
            • **Dry**: Feels tight, may flake
            • **Oily**: Shiny, prone to breakouts
            • **Combination**: Oily T-zone, dry elsewhere
            • **Sensitive**: Easily irritated

            **How to Determine Your Type:**

            1. Wash your face with a gentle cleanser
            2. Pat dry and wait 30 minutes
            3. Observe how your skin feels

            Understanding your skin type helps you choose the right products and build an effective routine.
            """,
            imageIcon: "face.smiling.fill",
            readTime: 5
        ),

        EducationalContent(
            title: "The Importance of Sunscreen",
            category: "Basics",
            content: """
            Daily sunscreen is the single most important step in preventing skin damage and premature aging.

            **Why Sunscreen Matters:**

            • Prevents UV damage and skin cancer
            • Reduces premature aging and wrinkles
            • Prevents hyperpigmentation and dark spots
            • Maintains even skin tone

            **How to Use:**

            1. Apply SPF 30+ every morning
            2. Use about 1/4 teaspoon for face
            3. Reapply every 2 hours when outdoors
            4. Don't forget neck and hands

            **Types of Sunscreen:**

            • **Physical**: Zinc oxide, titanium dioxide
            • **Chemical**: Absorbs UV rays
            • **Hybrid**: Combines both types

            Make sunscreen a non-negotiable part of your routine!
            """,
            imageIcon: "sun.max.fill",
            readTime: 4
        ),

        EducationalContent(
            title: "Building Your Skincare Routine",
            category: "Routines",
            content: """
            A simple, consistent routine is more effective than complicated regimens with too many products.

            **Morning Routine:**

            1. Cleanser - Remove overnight oils
            2. Toner - Balance pH (optional)
            3. Serum - Target specific concerns
            4. Moisturizer - Hydrate and protect
            5. Sunscreen - SPF 30+ minimum

            **Evening Routine:**

            1. Makeup Remover/Oil Cleanser
            2. Water-Based Cleanser (double cleanse)
            3. Toner - Prep skin
            4. Treatment/Serum - Active ingredients
            5. Eye Cream - Delicate area care
            6. Moisturizer - Night cream

            **Key Tips:**

            • Start simple, add products gradually
            • Patch test new products
            • Wait 4-6 weeks to see results
            • Consistency is key

            Remember: More products doesn't mean better results!
            """,
            imageIcon: "list.bullet.clipboard.fill",
            readTime: 7
        ),

        EducationalContent(
            title: "Understanding Active Ingredients",
            category: "Ingredients",
            content: """
            Active ingredients are the powerhouse components that deliver real results in skincare.

            **Popular Actives:**

            **Retinol (Vitamin A)**
            • Benefits: Anti-aging, acne treatment
            • Use: Start slow, PM only
            • Note: Can cause dryness initially

            **Vitamin C**
            • Benefits: Brightening, antioxidant
            • Use: AM routine
            • Note: Look for stable formulations

            **Niacinamide (Vitamin B3)**
            • Benefits: Pore refining, brightening
            • Use: AM or PM
            • Note: Gentle, suitable for most skin

            **Hyaluronic Acid**
            • Benefits: Hydration, plumping
            • Use: AM and PM
            • Note: Apply to damp skin

            **Salicylic Acid (BHA)**
            • Benefits: Acne treatment, exfoliation
            • Use: Start 2-3x weekly
            • Note: Oil-soluble, penetrates pores

            **AHA (Glycolic/Lactic Acid)**
            • Benefits: Exfoliation, brightening
            • Use: PM, 2-3x weekly
            • Note: Increases sun sensitivity

            Always introduce one active at a time and use sunscreen!
            """,
            imageIcon: "flask.fill",
            readTime: 8
        ),

        EducationalContent(
            title: "Managing Acne-Prone Skin",
            category: "Conditions",
            content: """
            Acne is one of the most common skin concerns, but it can be effectively managed with the right approach.

            **Understanding Acne:**

            • Caused by excess oil, bacteria, and inflammation
            • Can be hormonal, stress-related, or dietary
            • Different types: whiteheads, blackheads, cystic

            **Treatment Approach:**

            1. **Gentle Cleansing**
               - Wash 2x daily with salicylic acid cleanser
               - Don't over-wash or scrub harshly

            2. **Targeted Treatment**
               - Benzoyl peroxide for bacteria
               - Salicylic acid for oil control
               - Niacinamide to reduce inflammation

            3. **Moisturize**
               - Use oil-free, non-comedogenic products
               - Don't skip this step!

            4. **Lifestyle Factors**
               - Change pillowcases regularly
               - Don't touch your face
               - Manage stress levels
               - Stay hydrated

            **When to See a Dermatologist:**

            • Severe or cystic acne
            • Scarring
            • No improvement after 3 months
            • Hormonal acne patterns

            Remember: Consistency and patience are key!
            """,
            imageIcon: "bandage.fill",
            readTime: 6
        ),

        EducationalContent(
            title: "Hydration vs. Moisturization",
            category: "Basics",
            content: """
            Understanding the difference between hydration and moisturization is key to healthy skin.

            **Hydration:**

            • Adds water to skin cells
            • Ingredients: Hyaluronic acid, glycerin
            • Makes skin plump and dewy
            • Essential for all skin types

            **Moisturization:**

            • Seals in hydration with oils
            • Ingredients: Ceramides, oils, butters
            • Prevents water loss
            • Protects skin barrier

            **The Right Approach:**

            1. Apply hydrating products first (toner, serum)
            2. Follow with moisturizer to seal it in
            3. Apply to damp skin for best results

            **Signs You Need More:**

            **Hydration:**
            • Dull, tired-looking skin
            • Fine dehydration lines
            • Tight feeling

            **Moisturization:**
            • Flaking or peeling
            • Rough texture
            • Redness or sensitivity

            You need both for optimal skin health!
            """,
            imageIcon: "drop.fill",
            readTime: 5
        )
    ]

    var filteredArticles: [EducationalContent] {
        if selectedCategory == "All" {
            return articles
        }
        return articles.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)

                            Text("Learn About Skincare")
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        Text("Evidence-based information to help you make informed decisions about your skin health")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(20)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                CategoryButton(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Articles Grid
                    LazyVStack(spacing: 16) {
                        ForEach(filteredArticles) { article in
                            ArticleCard(article: article)
                                .onTapGesture {
                                    selectedArticle = article
                                }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Learning Hub")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
        }
    }
}

struct ArticleCard: View {
    let article: EducationalContent

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: article.imageIcon)
                    .font(.title2)
                    .foregroundStyle(categoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(article.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor)

                Text(article.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label("\(article.readTime) min read", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    var categoryColor: Color {
        switch article.category {
        case "Basics": return .blue
        case "Ingredients": return .purple
        case "Routines": return .green
        case "Conditions": return .orange
        default: return .gray
        }
    }
}

struct ArticleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let article: EducationalContent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(article.category)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)

                        Text(article.title)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack(spacing: 16) {
                            Label("\(article.readTime) min read", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Label("Verified", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider()
                        .padding(.horizontal, 20)

                    // Content
                    Text(article.content)
                        .font(.body)
                        .lineSpacing(6)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

#Preview {
    LearningHubView()
}
