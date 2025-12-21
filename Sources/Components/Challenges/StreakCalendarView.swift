import SwiftUI

struct StreakCalendarView: View {
    let streakData: StreakData
    
    private let calendar = Calendar.current
    private let daysToShow = 7
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("\(streakData.currentStreak)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Day Streak")
                            .font(.system(size: 16))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                    
                    Text("Record: \(streakData.longestStreak) days")
                        .font(.system(size: 13))
                        .foregroundColor(Color("LyoAccent"))
                }
                
                Spacer()
            }
            
            // Calendar Grid
            HStack(spacing: 8) {
                ForEach(recentDays, id: \.self) { date in
                    VStack(spacing: 6) {
                        Text(dayName(date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color("LyoTextSecondary"))
                        
                        ZStack {
                            Circle()
                                .fill(isStreakDay(date) ? Color("Primary").opacity(0.2) : Color("LyoSurface"))
                                .frame(width: 40, height: 40)
                            
                            if isStreakDay(date) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                            } else {
                                Text(dayNumber(date))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("LyoTextSecondary").opacity(0.5))
                            }
                        }
                        
                        if isToday(date) {
                            Circle()
                                .fill(Color("LyoAccent"))
                                .frame(width: 4, height: 4)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            
            // Motivational text
            if streakData.currentStreak >= 7 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("Amazing streak! Keep it going!")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color("LyoAccent"))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoSurface"))
        )
    }
    
    private var recentDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<daysToShow).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }.reversed()
    }
    
    private func isStreakDay(_ date: Date) -> Bool {
        streakData.streakDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
