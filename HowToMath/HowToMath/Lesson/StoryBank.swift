//
//  StoryBank.swift
//  HowToMath
//

import Foundation

/// Dresses a bare operation as a word problem.
///
/// The numbers are decided first and the sentence is wrapped around them, so a
/// story problem is never easier or harder than the plain one it replaces — only
/// the reading changes. Every noun is feminine plural, which keeps agreement
/// correct without needing a grammar table.
enum StoryBank {

    private static let names = [
        "João", "Ana", "Léo", "Bia", "Caio", "Duda", "Tom", "Nina", "Rui", "Alice"
    ]

    private static let things = [
        "figurinhas", "moedas", "bolinhas", "cartas", "balas", "canetas", "pedrinhas"
    ]

    private static let containers = [
        ("caixa", "caixas"), ("sacola", "sacolas"), ("bandeja", "bandejas"), ("mesa", "mesas")
    ]

    /// The blank that stands in for the missing number. Kept as one token so the
    /// screen can find it and paint it as an empty field.
    static let blank = "____"

    private static let wants = [
        ("uma guitarra", "custa"), ("uma bicicleta", "custa"),
        ("um skate", "custa"), ("um tênis", "custa"), ("uma mochila", "custa")
    ]

    /// A sentence with a hole where an operand should be: you hold `have`, the
    /// whole is `total`, and the blank is the distance between them.
    static func gapText(have: Int, total: Int) -> String {
        let name = names.randomElement()!
        let (item, verb) = wants.randomElement()!
        let thing = things.randomElement()!

        let templates = [
            "\(name) tem \(have) reais e precisa de mais \(blank) para comprar \(item), que \(verb) \(total).",
            "\(name) já leu \(have) páginas e faltam \(blank) para terminar o livro de \(total).",
            "\(name) tinha \(have) \(thing) e ganhou mais \(blank), ficando com \(total).",
            "Para encher a caixa de \(total) \(thing), \(name) já colocou \(have) e ainda faltam \(blank)."
        ]
        return templates.randomElement()!
    }

    static func text(left: Int, right: Int, operation: MathOperation) -> String {
        let name = names.randomElement()!
        let thing = things.randomElement()!

        switch operation {
        case .add:
            let templates = [
                "\(name) tinha \(left) \(thing) e ganhou mais \(right). Com quantas ficou?",
                "\(name) juntou \(left) \(thing) pela manhã e \(right) à tarde. Quantas juntou no dia?",
                "Numa gaveta há \(left) \(thing) e na outra há \(right). Quantas são ao todo?"
            ]
            return templates.randomElement()!

        case .subtract:
            let templates = [
                "\(name) tinha \(left) \(thing) e deu \(right) para um amigo. Quantas sobraram?",
                "\(name) tinha \(left) \(thing) e perdeu \(right) no caminho. Com quantas ficou?",
                "Havia \(left) \(thing) na mesa e \(right) foram guardadas. Quantas ficaram na mesa?"
            ]
            return templates.randomElement()!

        case .multiply:
            let (one, many) = containers.randomElement()!
            let templates = [
                "Cada \(one) tem \(right) \(thing). Quantas \(thing) há em \(left) \(many)?",
                "\(name) arrumou \(left) \(many) com \(right) \(thing) em cada uma. Quantas \(thing) arrumou?",
                "São \(left) \(many), e em cada uma cabem \(right) \(thing). Quantas \(thing) cabem no total?"
            ]
            return templates.randomElement()!
        }
    }
}
