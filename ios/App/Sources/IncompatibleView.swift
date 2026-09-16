// The screen for a phone Arivu will not run on.
//
// It has NO BUTTON. iOS gives an app no way to delete itself, `exit()` reads as a crash and is
// refused by review, and a dead button or a link into Settings that lands nowhere would both be
// worse than a sentence that tells the truth (leaves/design.md §5.4, D-042).
//
// There is no "continue anyway" (R8), no close, no crash. The App Store has no device-exclusion
// catalogue, so more iOS users will see this than Android users ever do — it is a first impression,
// not an edge case, and it is written as one.
//
// UNVERIFIED: not compiled.
//
// spine: C6, R8

import ArivuCore
import SwiftUI

struct IncompatibleView: View {
    let failure: GateFailure

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Strings.string(.incompatible_title))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(reason)
                    .font(.body)
                Text(Strings.string(.incompatible_body))
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)
                // In place of the Android "Uninstall Arivu" button.
                Text(Strings.string(.incompatible_remove_ios))
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Palette.surface)
        .foregroundStyle(Palette.onSurface)
    }

    /// Only two of the four checks can fail on an iPhone: every supported device is arm64 and iOS
    /// has no low-RAM flag. The other two are still handled, because the evaluator is shared with
    /// Android (C11) and a silent blank screen would be worse than a slightly odd sentence.
    private var reason: String {
        switch failure {
        case .totalRam(let actual, let required):
            return Strings.string(.gate_total_ram, ByteSize.si(actual), ByteSize.si(required))
        case .storage(let actual, let required):
            return Strings.string(.gate_storage, ByteSize.si(actual), ByteSize.si(required))
        case .noArm64, .lowRamDevice:
            return Strings.string(.incompatible_body)
        }
    }
}
