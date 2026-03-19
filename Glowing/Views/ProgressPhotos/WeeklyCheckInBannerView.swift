import SwiftUI
import SwiftData

struct WeeklyCheckInBannerView: View {
    @Query(sort: \ProgressPhoto.capturedAt, order: .reverse) private var allPhotos: [ProgressPhoto]
    @State private var checkInManager = CheckInManager.shared

    var onTakePhotos: () -> Void

    private var isDue: Bool {
        checkInManager.isDueForCheckIn(photos: allPhotos)
    }

    private var daysSince: Int {
        checkInManager.daysSinceLastCheckIn(photos: allPhotos)
    }

    private var streak: Int {
        checkInManager.weeklyCheckInStreak(photos: allPhotos)
    }

    var body: some View {
        if isDue {
            Button(action: onTakePhotos) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(daysSince > 10 ? .orange : .blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Check-In")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if daysSince > 0 {
                            Text("\(daysSince) days since last check-in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Take your weekly progress photos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(streak)")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(daysSince > 10 ? Color.orange.opacity(0.1) : Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
