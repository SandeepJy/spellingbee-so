import SwiftUI

struct GameReviewView: View {
    let game: MultiUserGame
    let correctlySpelledWords: [String]
    let misspelledWords: [MisspelledWord]
    @Environment(\.dismiss) var dismiss
    @State private var selectedWord: WordReviewData? = nil
    @State private var filterOption: ReviewFilterOption = .all
    
    enum ReviewFilterOption: String, CaseIterable {
        case all = "All"
        case correct = "Correct"
        case incorrect = "Incorrect"
    }
    
    private var reviewData: [WordReviewData] {
        game.words.map { word in
            let wasCorrect = correctlySpelledWords.contains(word.word)
            let userAnswer = misspelledWords.first { $0.correctWord == word.word }?.userAnswer
            return WordReviewData(
                word: word,
                wasCorrect: wasCorrect,
                userAnswer: userAnswer
            )
        }
    }
    
    private var filteredReviewData: [WordReviewData] {
        switch filterOption {
        case .all:
            return reviewData
        case .correct:
            return reviewData.filter { $0.wasCorrect }
        case .incorrect:
            return reviewData.filter { !$0.wasCorrect }
        }
    }
    
    private var correctCount: Int {
        reviewData.filter { $0.wasCorrect }.count
    }
    
    private var incorrectCount: Int {
        reviewData.filter { !$0.wasCorrect }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary header
                ReviewSummaryHeader(
                    correctCount: correctCount,
                    incorrectCount: incorrectCount,
                    totalCount: game.wordCount
                )
                .padding()
                
                // Filter picker
                Picker("Filter", selection: $filterOption) {
                    ForEach(ReviewFilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Word list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if filteredReviewData.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: filterOption == .correct ? "checkmark.circle" : "xmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No \(filterOption.rawValue.lowercased()) words")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(Array(filteredReviewData.enumerated()), id: \.element.id) { index, wordData in
                                WordReviewRow(
                                    wordData: wordData,
                                    index: reviewData.firstIndex(where: { $0.id == wordData.id }) ?? index,
                                    onTap: {
                                        selectedWord = wordData
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Review Words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedWord) { wordData in
                WordDetailSheet(wordData: wordData)
            }
        }
    }
}

