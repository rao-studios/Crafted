import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

extension Home {
    var view: some View {
        let role = preferences.state.role ?? .designer
        let generations = library.state.generations
        let pending = state.pendingDelete.flatMap { library.state.generation($0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: .layer5) {
                HomeHeader(role: role, busy: forge.state.isBusy)
                DropLeaf(prompt: role.dropPrompt, targeted: state.targeted, pointer: UnitPoint(x: state.pointerX, y: state.pointerY))
                    .frame(height: CraftLayout.Library.leafHeight)
                    .onDrop(of: FolderDrop.types, delegate: LeafDrop(targeted: center.$state.binding.targeted,
                                                                     x: center.$state.binding.pointerX,
                                                                     y: center.$state.binding.pointerY,
                                                                     height: CraftLayout.Library.leafHeight))
                if let proposal = environment.state.proposal {
                    ProposalCard(proposal: proposal, role: role, busy: forge.state.isBusy, problem: forge.state.problem)
                } else if let problem = forge.state.problem {
                    Text(problem).craftType(.caption).foregroundStyle(Color.craftError).textSelection(.enabled)
                }
                LibraryGrid(generations: generations, listings: library.state.listings, icons: library.state.icons,
                            iconRevision: library.state.iconRevision, run: forge.state.run, exports: forge.state.exports)
            }
            .padding(.horizontal, .layer5)
            .padding(.top, .layer6)
            .padding(.bottom, .layer5)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onBubble {
            On(.homeChooseFolder) { CraftedAppRoot.shared.chooseFolder() }
            On(.homeRole, CraftedRole.self) { preferences.set(.role($0)) }
            On(.proposalStart) { CraftedAppRoot.shared.startProposal() }
            On(.proposalDismiss) { CraftedAppRoot.shared.dismissProposal() }
            On(.tileOpen, String.self) { CraftedAppRoot.shared.open(generation: $0) }
            On(.tileUpdate, String.self) { CraftedAppRoot.shared.updateFromFolder($0) }
            On(.tileFinder, String.self) { CraftedAppRoot.shared.showInFinder($0) }
            On(.tileResume, String.self) { CraftedAppRoot.shared.resume($0) }
            On(.tileDelete, String.self) { _state.pendingDelete.wrappedValue = $0 }
        }
        .confirmationDialog(
            pending.map { "Delete \($0.title)?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { _state.pendingDelete.wrappedValue = nil } }),
            titleVisibility: .visible
        ) {
            if let target = pending {
                Button("Delete", role: .destructive) {
                    _state.pendingDelete.wrappedValue = nil
                    CraftedAppRoot.shared.delete(target.id)
                }
            }
            Button("Cancel", role: .cancel) { _state.pendingDelete.wrappedValue = nil }
        } message: {
            if let target = pending {
                Text("Its run, its listing, its icon and its package go. Archives you downloaded stay where you saved them; \(target.sourceName) is not touched.")
            }
        }
        .task { library.refreshSoon() }
    }
}

/// The leaf's drop: where the pointer is (for the bloom) and the folder when it lands.
struct LeafDrop: DropDelegate {
    @Binding var targeted: Bool
    @Binding var x: Double
    @Binding var y: Double
    let height: CGFloat

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: FolderDrop.types) }

    func dropEntered(info: DropInfo) {
        targeted = true
        follow(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        follow(info)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) { targeted = false }

    func performDrop(info: DropInfo) -> Bool {
        targeted = false
        return FolderDrop.open(info.itemProviders(for: FolderDrop.types))
    }

    private func follow(_ info: DropInfo) {
        // The leaf's width is the window's less its margins; the height is fixed. Close enough for a bloom.
        let width = max(1, (NSApp.keyWindow?.contentView?.bounds.width ?? 900) - 2 * .layer5)
        x = min(max(Double(info.location.x / width), 0), 1)
        y = min(max(Double(info.location.y / height), 0), 1)
    }
}

extension GraniteBubble.Name {
    static let homeChooseFolder: Self = "HomeHeader.chooseFolder"
    static let homeRole: Self = "HomeHeader.role"
    static let proposalStart: Self = "ProposalCard.start"
    static let proposalDismiss: Self = "ProposalCard.dismiss"
    static let tileOpen: Self = "GenerationTile.open"
    static let tileUpdate: Self = "GenerationTile.update"
    static let tileFinder: Self = "GenerationTile.finder"
    static let tileResume: Self = "GenerationTile.resume"
    static let tileDelete: Self = "GenerationTile.delete"
}
