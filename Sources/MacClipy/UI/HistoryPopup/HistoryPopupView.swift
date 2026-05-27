import SwiftUI

struct HistoryPopupView: View {
    @Bindable var model: HistoryPopupModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            header
            filters
            resultsList
        }
        .padding(14)
        .frame(width: 520, height: 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .background(
            KeyboardEventBridge { event, isTextEditing in
                HistoryPopupKeyAction.handle(event: event, isTextEditing: isTextEditing, model: model)
            }
        )
        .onAppear {
            searchFocused = true
        }
        .onChange(of: model.query) {
            model.selectedRow = 0
            model.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TextField(L10n.tr("historyPopup.searchPlaceholder"), text: $model.query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .id(model.presentationRevision)
                .onChange(of: model.presentationRevision) {
                    searchFocused = true
                }

            Button {
                model.requestSettings()
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel(L10n.tr("button.settings"))
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("button.settings"))
        }
    }

    private var filters: some View {
        HStack(spacing: 10) {
            Picker(selection: $model.mode) {
                Text(L10n.tr("historyPopup.filter.all")).tag(HistoryPopupModel.Mode.all)
                Text(L10n.tr("historyPopup.filter.favorites")).tag(HistoryPopupModel.Mode.favorites)
            } label: {
                Text(L10n.tr("historyPopup.filter.title"))
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .onChange(of: model.mode) {
                if model.mode == .all {
                    model.folderFilter = .all
                }
                model.selectedRow = 0
                model.refresh()
            }

            Picker(selection: $model.folderFilter) {
                Text(L10n.tr("historyPopup.folders.all")).tag(FavoriteFolderFilter.all)
                Text(L10n.tr("historyPopup.folders.unclassified")).tag(FavoriteFolderFilter.unclassified)
                ForEach(model.folders) { folder in
                    Text(verbatim: folder.name).tag(FavoriteFolderFilter.folder(folder.id))
                }
            } label: {
                Text(L10n.tr("historyPopup.folders.title"))
            }
            .disabled(model.mode == .all)
            .onChange(of: model.folderFilter) {
                model.mode = .favorites
                model.selectedRow = 0
                model.refresh()
            }
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if model.results.isEmpty {
                        Text(L10n.tr("historyPopup.noMatches"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { row, result in
                            HistoryPopupRow(
                                result: result,
                                isSelected: row == model.selectedRow,
                                onChoose: {
                                    model.chooseItem(id: result.id)
                                },
                                onToggleFavorite: {
                                    model.toggleFavorite(id: result.id)
                                }
                            )
                            .id(row)
                        }
                    }
                }
            }
            .onChange(of: model.selectedRow) {
                withAnimation(.snappy(duration: 0.12)) {
                    proxy.scrollTo(model.selectedRow, anchor: .center)
                }
            }
            .onChange(of: model.revision) {
                proxy.scrollTo(model.selectedRow, anchor: .center)
            }
        }
    }
}

private struct HistoryPopupRow: View {
    let result: HistoryPopupResult
    let isSelected: Bool
    let onChoose: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: result.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let detail = result.detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: result.favorite == nil ? "star" : "star.fill")
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(result.favorite == nil ? .secondary : .yellow)
                    .accessibilityLabel(L10n.tr("favorites.toggle"))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("favorites.toggle"))
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.26) : Color.clear)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.38), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: onChoose)
    }
}
