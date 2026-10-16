import Foundation
@testable import PrestoCVCore

/// Short CVs as people write them in the app: a nurse in English, Italian and German, with two jobs, one degree,
/// a few skills, languages, a certificate and a link or two. Their content is that of the CVs of the product review
/// of 2026-10-16, under invented names. Each runs a few lines over one page with the normal spacing of
/// Professional and Minimal.
enum EverydayCVs {

    /// A CV, with texts from its first and its last sections that must be in the PDF whatever the pagination
    struct Everyday {
        let label: String
        let cv: CVModel
        let markers: [String]
    }

    static let all: [Everyday] = [
        Everyday(label: "nurse-en", cv: nurseEnglish(),
                 markers: ["Registered nurse with 4 years", "Southmead Hospital", "NMC Registered Nurse (Adult)", "linkedin.com/in/saraconti"]),
        Everyday(label: "nurse-it", cv: nurseItalian(),
                 markers: ["Infermiera con sette anni", "Cooperativa Il Sorriso", "BLSD", "linkedin.com/in/lauraferri", "Ciclismo"]),
        Everyday(label: "nurse-de", cv: nurseGerman(),
                 markers: ["Examinierter Pflegefachmann", "Universitätsklinikum Würzburg", "Praxisanleiter", "Fotografie"])
    ]

    static func nurseEnglish() -> CVModel {
        CVModel(
            name: "Staff nurse",
            personalInfo: PersonalInfo(
                name: "Sara Conti", title: "Registered Nurse", location: "Bristol, UK", email: "sara.conti@example.com",
                phone: "+44 7700 900123",
                profile: "Registered nurse with 4 years of experience on acute medical and surgical wards. Calm under pressure, "
                    + "careful with medication and documentation, and good at explaining care plans to patients and families. "
                    + "Looking for a staff nurse role in a teaching hospital."
            ),
            relevant_experience: [
                Experience(title: "Staff Nurse", company: "Southmead Hospital, North Bristol NHS Trust", location: "Bristol",
                           period: "Mar 2022 – Present",
                           description: "Care for up to 8 patients per shift on a 28-bed acute medical ward. Administer medication, "
                               + "IV therapy and wound care. Mentor student nurses and new starters. Led the ward's falls-prevention "
                               + "audit, which cut falls by a third in one year."),
                Experience(title: "Newly Qualified Nurse", company: "Royal United Hospital", location: "Bath",
                           period: "Sep 2020 – Feb 2022",
                           description: "Rotational post across cardiology and general surgery. Prepared patients for theatre and "
                               + "managed post-operative recovery. Completed IV and venepuncture competencies.")
            ],
            education: [
                Education(degree: "BSc (Hons) Adult Nursing", school: "University of the West of England, Bristol", period: "2017 – 2020")
            ],
            skills: [
                Skill(name: "Medication administration", level: 3), Skill(name: "IV therapy and cannulation"),
                Skill(name: "Wound care"), Skill(name: "Patient assessment (NEWS2)"), Skill(name: "Electronic patient records")
            ],
            languages: [Language(name: "Italian", level: .native), Language(name: "English", level: .c2)],
            certifications: [Certification(name: "NMC Registered Nurse (Adult)", issuer: "Nursing and Midwifery Council", year: 2020)],
            social: [Social(platform: "LinkedIn", url: "linkedin.com/in/saraconti")],
            documentLanguage: "en"
        )
    }

    static func nurseItalian() -> CVModel {
        CVModel(
            name: "CV Infermiera",
            personalInfo: PersonalInfo(
                name: "Laura Ferri", title: "Infermiera", location: "Torino", email: "laura.ferri@example.com",
                phone: "+39 333 123 4567",
                profile: "Infermiera con sette anni di esperienza in cardiologia e assistenza domiciliare. Attenta, precisa e "
                    + "abituata a lavorare in équipe multidisciplinari. Cerco un ruolo in un reparto di terapia intensiva."
            ),
            relevant_experience: [
                Experience(title: "Infermiera di reparto", company: "Città della Salute e della Scienza – Ospedale Molinette",
                           location: "Torino", period: "Marzo 2019 – oggi",
                           description: "- Assistenza a 12 pazienti per turno in cardiologia\n"
                               + "- Monitoraggio ECG e gestione delle terapie endovenose\n"
                               + "- Formazione di 6 nuovi colleghi e tutoraggio degli studenti"),
                Experience(title: "Infermiera domiciliare", company: "Cooperativa Il Sorriso", location: "Moncalieri",
                           period: "2016 – 2019",
                           description: "Assistenza domiciliare a pazienti anziani e cronici; medicazioni avanzate ed educazione "
                               + "sanitaria ai caregiver.")
            ],
            education: [
                Education(degree: "Laurea in Infermieristica", school: "Università degli Studi di Torino", period: "2013 – 2016",
                          description: "Tesi sulla prevenzione delle cadute in età geriatrica (110/110 e lode).")
            ],
            skills: ["Monitoraggio ECG", "Medicazioni avanzate", "Terapia endovenosa", "Educazione del paziente", "Lavoro in équipe"]
                .map { Skill(name: $0) },
            languages: [Language(name: "Italiano", level: .native), Language(name: "Inglese", level: .b2), Language(name: "Francese", level: .a2)],
            certifications: [
                Certification(name: "BLSD – Basic Life Support e defibrillazione", issuer: "IRC Italian Resuscitation Council", year: 2023)
            ],
            interests: ["Canto corale", "Ciclismo"],
            social: [Social(platform: "LinkedIn", url: "https://www.linkedin.com/in/lauraferri")],
            documentLanguage: "it"
        )
    }

    static func nurseGerman() -> CVModel {
        CVModel(
            name: "Lebenslauf Pflege",
            personalInfo: PersonalInfo(
                name: "Lukas Becker", title: "Pflegefachmann", location: "Würzburg", email: "lukas.becker@example.com",
                phone: "+49 151 2345 6789",
                profile: "Examinierter Pflegefachmann mit fünf Jahren Erfahrung auf der Intensivstation. Belastbar, zuverlässig "
                    + "und teamorientiert. Ich suche eine Stelle mit Weiterbildungsmöglichkeiten in der Anästhesiepflege."
            ),
            relevant_experience: [
                Experience(title: "Pflegefachmann Intensivstation", company: "Universitätsklinikum Würzburg", location: "Würzburg",
                           period: "04/2021 – heute",
                           description: "- Betreuung von bis zu 3 beatmeten Patienten pro Schicht\n"
                               + "- Praxisanleitung für Auszubildende\n"
                               + "- Mitarbeit im Qualitätszirkel Hygiene"),
                Experience(title: "Gesundheits- und Krankenpfleger", company: "Klinikum Schweinfurt", location: "Schweinfurt",
                           period: "10/2019 – 03/2021",
                           description: "Allgemeine Innere Medizin; Grund- und Behandlungspflege, Wundversorgung, Dokumentation.")
            ],
            education: [
                Education(degree: "Ausbildung zum Gesundheits- und Krankenpfleger", school: "Berufsfachschule für Krankenpflege Würzburg",
                          period: "2016 – 2019")
            ],
            skills: ["Intensivpflege", "Beatmung", "Wundmanagement", "Praxisanleitung"].map { Skill(name: $0) },
            languages: [Language(name: "Deutsch", level: .native), Language(name: "Englisch", level: .b2)],
            certifications: [
                Certification(name: "Praxisanleiter (300 Stunden)", issuer: "Bayerische Krankenhausgesellschaft", year: 2022)
            ],
            interests: ["Handball", "Fotografie"],
            documentLanguage: "de"
        )
    }
}
