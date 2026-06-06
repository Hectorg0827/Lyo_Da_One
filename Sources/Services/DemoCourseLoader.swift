//
//  DemoCourseLoader.swift
//  Lyo
//
//  Loads the "Spanish 101" Demo Course for local testing of the Runtime.
//  Strictly adheres to LyoCourseProtocol.
//

import Foundation
import Combine

class DemoCourseLoader {
    static let shared = DemoCourseLoader()
    
    func loadSpanish101() -> LyoCourse {
        // Constructing the course strictly via code to ensure type safety
        // In prod, this comes from JSONDecoder
        
        // 1. Module 1: Basics
        let artifact1 = LyoArtifact(
            id: "art_s101_1_1_1",
            type: .conceptExplainer,
            renderTarget: "native",
            content: AnyCodable(ConceptExplainerPayload(
                markdown: """
                # Hola & Adiós
                
                Greetings are the foundation of any language. In Spanish, connection is key.
                
                ## Basic Greetings
                - **Hola**: Hello (Casual/Formal)
                - **Buenos días**: Good morning
                - **Buenas tardes**: Good afternoon
                
                ## Farewells
                - **Adiós**: Goodbye
                - **Hasta luego**: See you later
                """,
                hook: "You already know 'Hola'. But do you know how to say goodbye like a local?",
                visualPrompt: nil,
                keyTakeaways: ["Hola = Hello", "Adiós = Goodbye", "Hasta luego = See you later"]
            )),
            aiMetadata: nil
        )
        
        let artifact2 = LyoArtifact(
            id: "art_s101_1_1_2",
            type: .flashcards,
            renderTarget: "native",
            content: AnyCodable(LyoFlashcardsPayload(
                topic: "Basic Greetings",
                cards: [
                    LyoFlashcard(front: "Hola", back: "Hello", hint: "Universal greeting"),
                    LyoFlashcard(front: "Adiós", back: "Goodbye", hint: nil),
                    LyoFlashcard(front: "Hasta mañana", back: "See you tomorrow", hint: "Literal: Until tomorrow")
                ]
            )),
            aiMetadata: nil
        )
        
        let artifact3 = LyoArtifact(
            id: "art_s101_1_1_3",
            type: .quiz,
            renderTarget: "native",
            content: AnyCodable(LyoQuizArtifactPayload(
                questions: [
                    LyoQuizQuestion(
                        id: "q1",
                        text: "Which of these is used in the morning?",
                        type: "single_choice",
                        options: [
                            LyoQuizOption(id: "o1", text: "Buenas noches"),
                            LyoQuizOption(id: "o2", text: "Buenos días")
                        ],
                        correctOptionId: "o2",
                        explanation: "Buenos días means Good Morning."
                    )
                ]
            )),
            aiMetadata: nil
        )
        
        let lesson1 = LyoLesson(
            id: "les_1",
            title: "Essential Greetings",
            goal: "Master the art of saying hello and goodbye",
            artifacts: [artifact1, artifact2, artifact3],
            durationMinutes: 5
        )
        
        let module1 = LyoModule(
            id: "mod_1",
            title: "The Foundations",
            goal: "Start speaking immediately",
            lessons: [lesson1]
        )
        
        // 2. The Course
        return LyoCourse(
            id: "course_spanish_101",
            title: "Spanish 101: The Local Way",
            targetAudience: "Beginners",
            learningObjectives: ["Greetings", "Ordering Food", "Basic Directions"],
            modules: [module1],
            generationSource: "hybrid",
            version: "2.0",
            metadata: nil
        )
    }
}
