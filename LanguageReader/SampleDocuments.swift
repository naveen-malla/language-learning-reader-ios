import Foundation

struct SampleSeedDocument {
    let title: String
    let body: String
    let language: SupportedLanguage
}

enum SampleDocuments {
    static let german: [SampleSeedDocument] = [
        SampleSeedDocument(
            title: "German Practice Story",
            body: """
            Heute Morgen bin ich früh aufgestanden und habe das Fenster geöffnet. Die Straße war noch ruhig, und die Luft war kühl und klar.
            Ich habe mich mit einer Tasse Kaffee an den Tisch gesetzt und einen kurzen deutschen Artikel gelesen. Einige Wörter kannte ich schon, andere musste ich nachschlagen.

            Später hat mir eine Freundin eine Nachricht geschickt und vorgeschlagen, dass wir am Wochenende zusammen lernen. Sie meinte, dass regelmäßiges Lesen viel hilfreicher ist als seltene, lange Lernsitzungen.
            Wir wollen deshalb jeden Tag nur zwanzig Minuten lesen, neue Wörter markieren und am Abend kurz wiederholen.

            Am Nachmittag bin ich einkaufen gegangen. Im Supermarkt habe ich absichtlich auf die Beschriftungen geachtet, damit ich Wörter aus dem Alltag wiedererkenne.
            Zu Hause habe ich dann drei neue Wörter in meine Liste eingetragen und zu jedem Wort einen eigenen Beispielsatz geschrieben.

            Am Ende des Tages hatte ich nicht das Gefühl, sehr viel gelernt zu haben. Trotzdem konnte ich mehrere Sätze flüssiger lesen als gestern.
            Genau das motiviert mich: kleine Fortschritte, die sich mit der Zeit zu echtem Verständnis aufbauen.
            """,
            language: .german
        ),
        SampleSeedDocument(
            title: "German Reading: Daily Learning",
            body: """
            Beim Sprachenlernen ist Regelmäßigkeit wichtiger als Perfektion. Viele Lernende warten auf den richtigen Moment, aber meistens reicht ein kurzer, klarer Ablauf.
            Lies einen Abschnitt aufmerksam, markiere unbekannte Wörter und überprüfe danach nur die wichtigsten Begriffe.

            Wenn du jedes unbekannte Wort sofort nachschlägst, verlierst du leicht den roten Faden. Es ist oft besser, zuerst den ganzen Satz zu verstehen und danach einzelne Wörter genauer anzusehen.
            So trainierst du nicht nur den Wortschatz, sondern auch dein Gefühl für Struktur, Ton und Zusammenhang.

            Besonders hilfreich ist es, neue Wörter schnell wiederzuverwenden. Schreibe einen kurzen Beispielsatz, lies ihn laut vor und prüfe am nächsten Tag, ob du die Bedeutung noch erinnerst.
            Dieser kleine Kreislauf aus Lesen, Verstehen und Wiederholen hält den Lernaufwand niedrig und verbessert trotzdem die Erinnerung deutlich.

            Mit der Zeit werden vertraute Wörter häufiger, und schwierige Texte wirken weniger anstrengend. Das Ziel ist nicht, jedes Detail sofort zu kennen.
            Das Ziel ist, Schritt für Schritt sicherer zu lesen und immer weniger Hilfe zu brauchen.
            """,
            language: .german
        )
    ]

    static let kannada: [SampleSeedDocument] = [
        SampleSeedDocument(
            title: "Kannada Practice Story",
            body: """
            ಇಂದು ಬೆಳಿಗ್ಗೆ ನಾನು ಬೇಗ ಎದ್ದೆ. ಮನೆಯ ಹೊರಗೆ ತಂಪಾದ ಗಾಳಿ ಬೀಸುತ್ತಿತ್ತು.
            ರಸ್ತೆಯಲ್ಲಿ ಕಡಿಮೆ ವಾಹನಗಳು ಇದ್ದವು, ಆದ್ದರಿಂದ ಊರು ತುಂಬಾ ಶಾಂತವಾಗಿತ್ತು.
            ನಾನು ಕೈಯಲ್ಲಿ ಒಂದು ಪುಸ್ತಕ ಹಿಡಿದು ಬಾಗಿಲಿನ ಬಳಿ ಕುಳಿತು ಓದುತ್ತಿದ್ದೆ.
            ಸ್ವಲ್ಪ ಸಮಯದ ನಂತರ ನನ್ನ ಸ್ನೇಹಿತನು ಕರೆ ಮಾಡಿ ಹೊಸ ಯೋಜನೆ ಬಗ್ಗೆ ಮಾತನಾಡಿದನು.

            ಅವನು ಹೇಳಿದ ಯೋಜನೆ ಸರಳವಾಗಿತ್ತು ಆದರೆ ಬಹಳ ಉಪಯುಕ್ತವಾಗಿತ್ತು.
            ಪ್ರತಿದಿನ ನಾವು ಹತ್ತು ಹೊಸ ಪದಗಳನ್ನು ಕಲಿಯಬೇಕು ಎಂದು ಅವನು ಸೂಚಿಸಿದನು.
            ಹೊಸ ಪದವನ್ನು ಕೇವಲ ಓದುವುದು ಸಾಕಾಗುವುದಿಲ್ಲ; ವಾಕ್ಯದಲ್ಲಿ ಬಳಸಬೇಕು ಎಂದು ಅವನು ನೆನಪಿಸಿದನು.
            ನಾವು ಒಬ್ಬರಿಗೊಬ್ಬರು ಪ್ರಶ್ನೆಗಳನ್ನು ಕೇಳಿ ಅರ್ಥವನ್ನು ಪರಿಶೀಲಿಸುವುದು ಎಂದು ನಿರ್ಧರಿಸಿದ್ದೇವೆ.

            ಮಧ್ಯಾಹ್ನ ನಾನು ಮಾರುಕಟ್ಟೆಗೆ ಹೋಗಿ ತರಕಾರಿ ಮತ್ತು ಹಣ್ಣುಗಳನ್ನು ತಂದೆ.
            ಅಲ್ಲಿ ಜನರ ಮಾತು ಕೇಳಿದಾಗ ಬೇರೆ ಬೇರೆ ಉಚ್ಚಾರಣೆಗಳ ವ್ಯತ್ಯಾಸ ಗಮನಕ್ಕೆ ಬಂತು.
            ಕೆಲವು ಪದಗಳು ಪರಿಚಿತವಾಗಿದ್ದವು, ಕೆಲವು ಪದಗಳು ಸಂಪೂರ್ಣ ಹೊಸದಾಗಿದ್ದವು.
            ಮನೆಗೆ ಬಂದ ನಂತರ ಆ ಹೊಸ ಪದಗಳನ್ನು ನನ್ನ ಟಿಪ್ಪಣಿ ಪುಸ್ತಕದಲ್ಲಿ ಬರೆದೆ.

            ಸಂಜೆ ನಾನು ಕುಟುಂಬದವರ ಜೊತೆ ಕೂತು ದಿನದ ಅನುಭವಗಳನ್ನು ಹಂಚಿಕೊಂಡೆ.
            ತಂದೆಯವರು ನಿಧಾನವಾಗಿ, ಸ್ಪಷ್ಟವಾಗಿ ಓದುವ ಅಭ್ಯಾಸ ಮಾಡು ಎಂದು ಸಲಹೆ ನೀಡಿದರು.
            ತಾಯಿಯವರು ಪ್ರತಿಯೊಂದು ಹೊಸ ಪದಕ್ಕೆ ಸರಳ ಅರ್ಥ ಕಂಡುಹಿಡಿದು ಉಳಿಸಿಕೊಳ್ಳು ಎಂದು ಹೇಳಿದರು.
            ದಿನದ ಕೊನೆಯಲ್ಲಿ ನಾನು ಕಲಿತ ಪದಗಳನ್ನು ಮರುಪಠಿಸಿ ನಾಳೆಯ ಗುರಿ ಬರೆದೆ.
            """,
            language: .kannada
        ),
        SampleSeedDocument(
            title: "Kannada Reading: Daily Learning",
            body: """
            ಭಾಷೆಯನ್ನು ಕಲಿಯುವಾಗ ನಿರಂತರ ಅಭ್ಯಾಸವೇ ಮುಖ್ಯ. ಮೊದಲ ದಿನಗಳಲ್ಲಿ ಓದುವ ವೇಗ ನಿಧಾನವಾಗಿರುವುದು ಸಹಜ.
            ಆದರೆ ಪ್ರತಿದಿನ ಸ್ವಲ್ಪ ಸಮಯ ಮೀಸಲಿಟ್ಟರೆ ಪದಗಳು ಕ್ರಮೇಣ ಪರಿಚಿತವಾಗುತ್ತವೆ.
            ಪರಿಚಿತ ಪದಗಳು ಹೆಚ್ಚಾದಂತೆ ಓದಿನ ಮೇಲೆ ಆತ್ಮವಿಶ್ವಾಸವೂ ಹೆಚ್ಚಾಗುತ್ತದೆ.

            ಓದುವಾಗ ತಿಳಿಯದ ಪದವನ್ನು ಕಂಡರೆ ತಕ್ಷಣ ಅರ್ಥ ನೋಡಬಹುದು.
            ಅರ್ಥ ತಿಳಿದ ನಂತರ ಆ ಪದವನ್ನು ನಿಮ್ಮ ಪದಸಂಗ್ರಹಕ್ಕೆ ಸೇರಿಸಿ.
            ನಂತರ ಆ ಪದವನ್ನು ಕನಿಷ್ಠ ಎರಡು ವಾಕ್ಯಗಳಲ್ಲಿ ಬಳಸುವ ಪ್ರಯತ್ನ ಮಾಡಿ.
            ವಾಕ್ಯದಲ್ಲಿ ಬಳಕೆ ಮಾಡಿದಾಗ ಪದ ನೆನಪಿನಲ್ಲಿ ಹೆಚ್ಚು ಕಾಲ ಉಳಿಯುತ್ತದೆ.

            ಕೆಲವೊಮ್ಮೆ ಒಂದೇ ಪದಕ್ಕೆ ಹಲವು ಅರ್ಥಗಳು ಇರಬಹುದು.
            ಅಂಥ ಸಂದರ್ಭದಲ್ಲಿ ವಾಕ್ಯದ ಸಂದರ್ಭವನ್ನು ಗಮನಿಸಿ ಸರಿಯಾದ ಅರ್ಥ ಆಯ್ಕೆಮಾಡಿ.
            ಸಂದರ್ಭದ ಅರಿವು ಇಲ್ಲದೆ ಮಾಡಿದ ಅನುವಾದ ಗೊಂದಲ ಉಂಟುಮಾಡಬಹುದು.
            ಆದ್ದರಿಂದ ಮೊದಲು ವಾಕ್ಯವನ್ನು ಸಂಪೂರ್ಣ ಓದಿ ನಂತರ ಪದದ ಅರ್ಥ ನೋಡಿ.

            ಮತ್ತೊಂದು ಉತ್ತಮ ಅಭ್ಯಾಸ ಎಂದರೆ ವಾಕ್ಯಗಳನ್ನು ಭಾಗಗಳಾಗಿ ಓದುವುದು.
            ಪ್ರತಿ ವಾಕ್ಯದಲ್ಲಿ ಕ್ರಿಯಾಪದವನ್ನು ಗುರುತಿಸಿ, ನಂತರ ಕರ್ತೃ ಮತ್ತು ಕರ್ಮವನ್ನು ಗುರುತಿಸಿ.
            ಈ ವಿಧಾನದಿಂದ ದೀರ್ಘ ವಾಕ್ಯಗಳೂ ಸುಲಭವಾಗಿ ಅರ್ಥವಾಗುತ್ತವೆ.
            ನಿಧಾನವಾಗಿ ನಿಮ್ಮ ಓದುವ ಗತಿ, ಅರ್ಥಗ್ರಹಣ ಮತ್ತು ಪದಸಂಪತ್ತು ಮೂವರೂ ಏರಿಕೆಯಾಗುತ್ತವೆ.

            ನೆನಪಿರಲಿ: ಚಿಕ್ಕ ಪ್ರಗತಿ ಕೂಡ ಪ್ರಗತியே.
            ಇಂದಿನ ಹತ್ತು ಪದಗಳು ನಾಳೆಯ ಸುಗಮ ಓದಿಗೆ ನೆಲೆ ಸಿದ್ಧಪಡಿಸುತ್ತವೆ.
            """,
            language: .kannada
        )
    ]

    static func initial(for language: SupportedLanguage) -> [SampleSeedDocument] {
        switch language {
        case .german:
            return german
        case .kannada:
            return kannada
        }
    }
}
