import Foundation

enum Goal: String, CaseIterable, Identifiable, Codable {
    case hypertrophy, strength, fatLoss, endurance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hypertrophy: "Kas kazanımı"
        case .strength: "Güç artışı"
        case .fatLoss: "Yağ yakımı"
        case .endurance: "Genel fitness"
        }
    }

    var icon: String {
        switch self {
        case .hypertrophy: "figure.strengthtraining.traditional"
        case .strength: "dumbbell.fill"
        case .fatLoss: "flame.fill"
        case .endurance: "heart.fill"
        }
    }

    var summary: String {
        switch self {
        case .hypertrophy: "Orta ağırlık, 6-12 tekrar, kas başına haftada 10-20 set."
        case .strength: "Ağır temel hareketler, 3-6 tekrar, uzun dinlenme."
        case .fatLoss: "Yüksek tempo, kısa dinlenme ve kondisyon hareketleri."
        case .endurance: "Hafif-orta ağırlık, 12-20 tekrar, dengeli gelişim."
        }
    }

    /// Kas grubu başına haftalık önerilen çalışma seti aralığı.
    var weeklySetRange: ClosedRange<Int> {
        switch self {
        case .hypertrophy: 10...20
        case .strength: 6...12
        case .fatLoss: 6...14
        case .endurance: 6...14
        }
    }
}

enum Level: String, CaseIterable, Identifiable, Codable {
    case beginner, intermediate, expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "Başlangıç"
        case .intermediate: "Orta"
        case .expert: "İleri"
        }
    }
}

enum EquipmentProfile: String, CaseIterable, Identifiable, Codable {
    case gym, dumbbells, bodyweight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gym: "Spor salonu"
        case .dumbbells: "Evde dambıl"
        case .bodyweight: "Sadece vücut ağırlığı"
        }
    }

    /// Veri setindeki ekipman adlarından hangilerine izin verildiği. nil = ekipmansız.
    func allows(_ equipment: String?) -> Bool {
        guard let equipment else { return true }
        switch self {
        case .gym:
            return true
        case .dumbbells:
            return ["dumbbell", "body only", "kettlebells", "bands", "exercise ball"].contains(equipment)
        case .bodyweight:
            return ["body only", "bands"].contains(equipment)
        }
    }
}

/// Veri setindeki 17 kası daha anlaşılır gruplara toplar.
enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, abs, lowerBack, quads, hamstrings, glutes, calves, neck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Göğüs"
        case .back: "Sırt"
        case .shoulders: "Omuz"
        case .biceps: "Pazu (biceps)"
        case .triceps: "Arka kol (triceps)"
        case .forearms: "Ön kol"
        case .abs: "Karın"
        case .lowerBack: "Bel"
        case .quads: "Ön bacak"
        case .hamstrings: "Arka bacak"
        case .glutes: "Kalça"
        case .calves: "Baldır"
        case .neck: "Boyun"
        }
    }

    /// Haftalık denge tablosunda gösterilen ana gruplar.
    static let tracked: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps, .abs, .quads, .hamstrings, .glutes, .calves]

    init?(datasetMuscle: String) {
        switch datasetMuscle {
        case "chest": self = .chest
        case "lats", "middle back", "traps": self = .back
        case "lower back": self = .lowerBack
        case "shoulders": self = .shoulders
        case "biceps": self = .biceps
        case "triceps": self = .triceps
        case "forearms": self = .forearms
        case "abdominals": self = .abs
        case "quadriceps": self = .quads
        case "hamstrings": self = .hamstrings
        case "glutes", "abductors", "adductors": self = .glutes
        case "calves": self = .calves
        case "neck": self = .neck
        default: return nil
        }
    }
}

enum Labels {
    static func muscle(_ raw: String) -> String {
        switch raw {
        case "abdominals": "Karın"
        case "abductors": "Dış kalça (abduktor)"
        case "adductors": "İç bacak (adduktor)"
        case "biceps": "Pazu (biceps)"
        case "calves": "Baldır"
        case "chest": "Göğüs"
        case "forearms": "Ön kol"
        case "glutes": "Kalça"
        case "hamstrings": "Arka bacak"
        case "lats": "Kanat (lats)"
        case "lower back": "Bel"
        case "middle back": "Orta sırt"
        case "neck": "Boyun"
        case "quadriceps": "Ön bacak (quadriceps)"
        case "shoulders": "Omuz"
        case "traps": "Trapez"
        case "triceps": "Arka kol (triceps)"
        default: raw.capitalized
        }
    }

    static func equipment(_ raw: String?) -> String {
        switch raw {
        case nil: "Ekipmansız"
        case "barbell": "Barbell (halter)"
        case "dumbbell": "Dambıl"
        case "body only": "Vücut ağırlığı"
        case "cable": "Kablo"
        case "machine": "Makine"
        case "kettlebells": "Kettlebell"
        case "bands": "Direnç bandı"
        case "medicine ball": "Sağlık topu"
        case "exercise ball": "Pilates topu"
        case "foam roll": "Foam roller"
        case "e-z curl bar": "EZ bar"
        case "other": "Diğer"
        case let value?: value.capitalized
        }
    }

    static func level(_ raw: String) -> String {
        Level(rawValue: raw)?.title ?? raw.capitalized
    }

    static func category(_ raw: String) -> String {
        switch raw {
        case "strength": "Kuvvet"
        case "stretching": "Esneme"
        case "plyometrics": "Pliometrik"
        case "powerlifting": "Powerlifting"
        case "olympic weightlifting": "Olimpik halter"
        case "strongman": "Strongman"
        case "cardio": "Kardiyo"
        default: raw.capitalized
        }
    }

    static func force(_ raw: String?) -> String? {
        switch raw {
        case "push": "İtiş"
        case "pull": "Çekiş"
        case "static": "Statik"
        default: nil
        }
    }

    static func mechanic(_ raw: String?) -> String? {
        switch raw {
        case "compound": "Bileşik (çok eklemli)"
        case "isolation": "İzolasyon (tek eklem)"
        default: nil
        }
    }
}
