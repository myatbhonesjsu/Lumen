//
//  FolderNamePromptSheet.swift
//  Lumen
//
//  Prompt user to name their analysis folder
//

import SwiftUI
import SwiftData

struct FolderNamePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkinMetric.timestamp, order: .reverse) private var allMetrics: [SkinMetric]
    let metric: SkinMetric
    let onComplete: () -> Void  // Callback to dismiss parent view

    @State private var folderName = ""
    @State private var selectedExistingFolder: String? = nil
    @FocusState private var isFocused: Bool
    @State private var showExistingFolders = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                }
                
                // Title and description
                VStack(spacing: 12) {
                    Text("Save Your Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Give this analysis a name to organize your skincare journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Existing folders section
                if !existingFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Existing Folders")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(existingFolders, id: \.self) { folder in
                                    Button(action: {
                                        selectedExistingFolder = folder
                                        folderName = folder
                                        showExistingFolders = false
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: selectedExistingFolder == folder ? "checkmark.circle.fill" : "folder.fill")
                                                .font(.subheadline)
                                            Text(folder)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(selectedExistingFolder == folder ? .white : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(selectedExistingFolder == folder ? Color.yellow : Color(.systemGray5))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Divider
                if !existingFolders.isEmpty {
                    Divider()
                        .padding(.horizontal, 20)
                }
                
                // Input field for new folder
                VStack(alignment: .leading, spacing: 8) {
                    Text(existingFolders.isEmpty ? "Folder Name" : "Or Create New Folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    TextField("e.g., \"Morning Routine\", \"Winter Care\"", text: $folderName)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .focused($isFocused)
                        .padding(.horizontal, 20)
                        .onChange(of: folderName) { _, newValue in
                            // Clear existing folder selection when typing
                            if !newValue.isEmpty && selectedExistingFolder != nil {
                                selectedExistingFolder = nil
                            }
                        }
                }
                
                // Quick suggestions (only if no existing folders selected)
                if selectedExistingFolder == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick suggestions:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: { 
                                        folderName = suggestion
                                        selectedExistingFolder = nil
                                    }) {
                                        Text(suggestion)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: save) {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(folderName.isEmpty ? Color.gray : Color.yellow)
                            .cornerRadius(12)
                    }
                    .disabled(folderName.isEmpty)
                    
                    Button(action: skipNaming) {
                        Text("Skip for Now")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
    
    private var existingFolders: [String] {
        // Get unique folder names from all metrics, excluding nil and current metric
        let folders = Set(allMetrics
            .filter { $0.id != metric.id && $0.folderName != nil }
            .compactMap { $0.folderName })
        return Array(folders).sorted()
    }
    
    private var suggestions: [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return ["Morning Routine", "AM Skincare", "Daily Check"]
        } else if hour < 17 {
            return ["Afternoon Check", "Midday Scan", "Touch-up"]
        } else {
            return ["Evening Routine", "PM Skincare", "Night Check"]
        }
    }
    
    private func save() {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        metric.folderName = trimmed
        do {
            try modelContext.save()
        } catch {
            print("Error saving folder name: \(error)")
        }

        // Dismiss folder prompt sheet
        dismiss()

        // Dismiss parent analysis view after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }

    private func skipNaming() {
        // Leave folderName as nil (will go to "Unsorted" folder)

        // Dismiss folder prompt sheet
        dismiss()

        // Dismiss parent analysis view after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }
}

