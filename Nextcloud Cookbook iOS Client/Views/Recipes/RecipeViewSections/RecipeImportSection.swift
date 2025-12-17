//
//  RecipeImportSection.swift
//  Nextcloud Cookbook iOS Client
//
//  Created by Vincent Meilinger on 07.03.24.
//

import Foundation
import SwiftUI


// MARK: - RecipeView Import Section

struct RecipeImportSection: View {
    @ObservedObject var viewModel: RecipeView.ViewModel
    var importRecipe: (String) async -> (RecipeImportResult?, UserAlert?)
    
    @State private var isImporting = false
    @State private var importWarnings: [RecipeImportWarning] = []
    @State private var showWarningBanner = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecondaryLabel(text: "Import Recipe")
            
            Text(LocalizedStringKey("Paste the url of a recipe you would like to import in the above, and we will try to fill in the fields for you. This feature does not work with every website. If your favourite website is not supported, feel free to reach out for help. You can find the contact details in the app settings."))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Warning banner for partial imports
            if showWarningBanner && !importWarnings.isEmpty {
                ImportWarningBanner(warnings: importWarnings) {
                    withAnimation {
                        showWarningBanner = false
                    }
                }
            }
            
            HStack {
                TextField(LocalizedStringKey("URL (e.g. example.com/recipe)"), text: $viewModel.importUrl)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isImporting)

                Button {
                    Task {
                        await performImport()
                    }
                } label: {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Text(LocalizedStringKey("Import"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isImporting || viewModel.importUrl.isEmpty)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).foregroundStyle(Color.primary.opacity(0.1)))
        .padding(5)
        .padding(.top, 5)
    }
    
    private func performImport() async {
        isImporting = true
        importWarnings = []
        showWarningBanner = false

        let (result, error) = await importRecipe(viewModel.importUrl)

        isImporting = false

        if let result = result {
            // Check for warnings in the result (successful import with warnings)
            var warnings = result.warnings

            // Also check for warnings in PARTIAL_IMPORT error
            if let importAlert = error as? RecipeImportAlert,
               case .PARTIAL_IMPORT(let errorWarnings) = importAlert {
                warnings.append(contentsOf: errorWarnings)
            }

            // Show warnings if any
            if !warnings.isEmpty {
                importWarnings = warnings
                // Store warnings in viewModel for field highlighting
                viewModel.importWarnings = warnings
                withAnimation {
                    showWarningBanner = true
                }
                return // Don't show error alert if we showed warnings
            }
        }

        if let error = error {
            // Show error alert (unless it's PARTIAL_IMPORT which we already handled above)
            if let importAlert = error as? RecipeImportAlert,
                case .PARTIAL_IMPORT = importAlert {
                // Already handled warnings above, don't show alert
            } else {
                viewModel.presentAlert(
                    RecipeAlert.CUSTOM(
                        title: error.localizedTitle,
                        description: error.localizedDescription
                    )
                )
            }
        }
    }
}
