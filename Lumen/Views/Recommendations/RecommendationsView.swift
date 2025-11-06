//
//  RecommendationsView.swift
//  Lumen
//
//  AI Skincare Assistant - Personalized Recommendations
//

import SwiftUI
import SwiftData

struct RecommendationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var skinMetrics: [SkinMetric]
    @State private var selectedCategory = "All"

    let categories = ["All", "Moisturizer", "Sunscreen", "Acne Treatment", "Cleanser"]

    var recommendations: [RecommendationItem] {
        guard let latestMetric = skinMetrics.first else {
            return defaultRecommendations
        }

        var items: [RecommendationItem] = []

        // Based on dryness
        if latestMetric.drynessLevel > 40 {
            items.append(RecommendationItem(
                title: "Hydrating Moisturizer",
                category: "Moisturizer",
                description: "Rich, non-greasy formula that provides 24-hour hydration",
                reason: "Your skin shows signs of dryness (\(Int(latestMetric.drynessLevel))%)",
                priority: 1,
                ingredients: ["Hyaluronic Acid", "Ceramides", "Glycerin"],
                price: "$24.99"
            ))
        }

        // Based on acne
        if latestMetric.acneLevel > 30 {
            items.append(RecommendationItem(
                title: "Gentle Acne Treatment",
                category: "Acne Treatment",
                description: "Non-drying formula with salicylic acid to treat and prevent breakouts",
                reason: "Detected acne concerns (\(Int(latestMetric.acneLevel))%)",
                priority: 2,
                ingredients: ["Salicylic Acid", "Niacinamide", "Tea Tree Oil"],
                price: "$18.99"
            ))
        }

        // Always recommend sunscreen
        items.append(RecommendationItem(
            title: "Daily SPF 50+ Sunscreen",
            category: "Sunscreen",
            description: "Broad-spectrum protection with lightweight, non-comedogenic formula",
            reason: "Essential for daily skin protection",
            priority: 1,
            ingredients: ["Zinc Oxide", "Vitamin E", "Green Tea Extract"],
            price: "$29.99"
        ))

        // Gentle cleanser
        items.append(RecommendationItem(
            title: "Gentle Foaming Cleanser",
            category: "Cleanser",
            description: "pH-balanced formula that cleanses without stripping natural oils",
            reason: "Foundation of any skincare routine",
            priority: 3,
            ingredients: ["Aloe Vera", "Chamomile", "Vitamin B5"],
            price: "$15.99"
        ))

        return items.sorted { $0.priority < $1.priority }
    }

    var filteredRecommendations: [RecommendationItem] {
        if selectedCategory == "All" {
            return recommendations
        }
        return recommendations.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)

                            Text("Personalized for You")
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        Text("Based on your latest skin analysis, we recommend these products to help improve your skin health")
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

                    // Recommendations List
                    LazyVStack(spacing: 16) {
                        ForEach(filteredRecommendations) { recommendation in
                            RecommendationCard(item: recommendation)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recommendations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    var defaultRecommendations: [RecommendationItem] {
        [
            RecommendationItem(
                title: "Daily SPF 50+ Sunscreen",
                category: "Sunscreen",
                description: "Broad-spectrum protection for all skin types",
                reason: "Essential for daily skin protection",
                priority: 1,
                ingredients: ["Zinc Oxide", "Vitamin E"],
                price: "$29.99"
            ),
            RecommendationItem(
                title: "Gentle Cleanser",
                category: "Cleanser",
                description: "pH-balanced formula for daily cleansing",
                reason: "Foundation of any skincare routine",
                priority: 2,
                ingredients: ["Aloe Vera", "Chamomile"],
                price: "$15.99"
            )
        ]
    }
}

struct RecommendationItem: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let description: String
    let reason: String
    let priority: Int
    let ingredients: [String]
    let price: String
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.yellow : Color.white)
                .cornerRadius(20)
        }
    }
}

struct RecommendationCard: View {
    let item: RecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                // Product Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: iconForCategory(item.category))
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(6)

                    Text(item.price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }

                Spacer()

                // Priority Badge
                if item.priority == 1 {
                    Text("Top Pick")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .cornerRadius(6)
                }
            }

            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.primary)

            // Reason
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(item.reason)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)

            // Key Ingredients
            VStack(alignment: .leading, spacing: 8) {
                Text("Key Ingredients")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.ingredients, id: \.self) { ingredient in
                            Text(ingredient)
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Action Button
            Button(action: {}) {
                HStack {
                    Text("Learn More")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.primary)
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 10, y: 4)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Moisturizer": return "drop.fill"
        case "Sunscreen": return "sun.max.fill"
        case "Acne Treatment": return "bandage.fill"
        case "Cleanser": return "bubbles.and.sparkles.fill"
        default: return "cart.fill"
        }
    }
}

#Preview {
    RecommendationsView()
        .modelContainer(for: SkinMetric.self, inMemory: true)
}
