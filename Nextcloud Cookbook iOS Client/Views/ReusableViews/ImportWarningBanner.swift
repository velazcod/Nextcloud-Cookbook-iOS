//
//  ImportWarningBanner.swift
//  Nextcloud Cookbook iOS Client
//

import SwiftUI

struct ImportWarningBanner: View {
    let warnings: [RecipeImportWarning]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text(LocalizedStringKey("Some fields could not be imported"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(warnings, id: \.self) { warning in
                    HStack(spacing: 6) {
                        Image(systemName: warningIcon(for: warning))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(warning.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(LocalizedStringKey("Please fill in the missing information below before saving."))
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func warningIcon(for warning: RecipeImportWarning) -> String {
        switch warning {
        case .missingIngredients:
            return "list.bullet"
        case .missingInstructions:
            return "text.alignleft"
        case .missingImage:
            return "photo"
        case .missingDescription:
            return "doc.text"
        case .missingTimes:
            return "clock"
        }
    }
}

// Conform to Hashable for ForEach
extension RecipeImportWarning: Hashable {}