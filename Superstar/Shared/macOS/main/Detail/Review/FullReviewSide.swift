//
//  FullReviewSide.swift
//  Superstar (macOS)
//
//  Created by Jordi Bruin on 21/07/2022.
//

import SwiftUI
import AppStoreConnect_Swift_SDK

struct FullReviewSide: View {
    
    @Binding var review: CustomerReview?
    @FocusState private var isReplyFocused: Bool
    @State var showReplyField = false
    
    @EnvironmentObject var reviewManager: ReviewManager
    @EnvironmentObject var appsManager: AppsManager
    
    @AppStorage("suggestions") var suggestions: [Suggestion] = []
    
    @State var isReplying = false
    @State var succesfullyReplied = false
    
    @State var isError = false
    @State var errorString = ""
    
    @State var showError = false
    
    @State var replyText = ""
    
    @AppStorage("onlyShowSuggestionsPerApp") var onlyShowSuggestionsPerApp: Bool = true
    
    var body: some View {
        VStack {
            ZStack {
                Color.gray.opacity(0.1)
                
                if let review = review {
                    reviewView(review: review)
                } else {
                    VStack {
                        Text("")
                    }
                }
            }
        }
        .frame(minWidth: 500)
        .overlay(
            ZStack {
                Color(.controlBackgroundColor)
                VStack {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 60))
                        .opacity(succesfullyReplied ? 1 : 0)
                        .animation(.default, value: isReplying)
                    
                    if isReplying {
                        ProgressView()
                    }
                    
                    Text(succesfullyReplied ? "Pending Publication" : "Sending Reply...")
                        .font(.system(.title, design: .rounded))
                        .bold()
                }
            }
                .opacity(isReplying || succesfullyReplied ? 1 : 0)
        )
        //        .toolbar(content: {
        //            ToolbarItem(content: {Spacer()})
        //            ToolbarItem(placement: .automatic) {
        //                Button {
        //                    getNewReview()
        //                } label: {
        //                    Text("Skip")
        //
        //                }
        //                .help(Text("Skip to another unanswered review (⌘S)"))
        //                .opacity(review == nil ? 0 : 1)
        //                .keyboardShortcut("s", modifiers: .command)
        //            }
        //        })
        .onChange(of: review) { newValue in
        
            // Clean the translated strings
            translator.translatedTitle = ""
            translator.translatedBody = ""
            //            reviewManager.replyText = ""
            isReplying = false
            succesfullyReplied = false
            replyText = ""
            isReplyFocused = true
            
            if showTranslate {
                translateString = "https://translate.google.com/?sl=auto&tl=en&text=\(review?.attributes?.title ?? "")\n\(review?.attributes?.body ?? "")&op=translate"
            }
        }
        
    }
    
    @AppStorage("pendingPublications") var pendingPublications: [String] = []
    
    func getNewReview() {
        guard let review = review else {
            return
        }
        
        guard let currentIndex = reviewManager.retrievedReviews.firstIndex(of: review) else {
            return
        }
        
        if let review = reviewManager.retrievedReviews.filter { !pendingPublications.contains($0.id ) }.randomElement() {
            self.review = review
        } else {
            print("No new reviews available")
        }
    }
    
    @State var showTranslation = false
    func reviewView(review: CustomerReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    starsFor(review: review)
                    title(for: review)
                    metadata(for: review)
                }
                body(for: review)
                
                HStack {
                    if !translator.translatedTitle.isEmpty {
                        Button {
                            translator.translatedBody = ""
                            translator.translatedTitle = ""
                        } label: {
                            Text("Show Original")
                        }
                    } else {
                        Button {
                            Task {
                                await deepLReview()
                            }
                        } label: {
                            Text("Translate")
                        }
                    }
                }
                
                if translator.detectedSourceLanguage != nil {
                    Text(translator.detectedSourceLanguage?.name ?? "No language found")
                }

                VStack {
                    extraOptions
                    translatorView
                    
                    if !translator.translatedReply.isEmpty {
                        Text(translator.translatedReply)
                            .textSelection(.enabled)
                    }
                    
                    replyArea
                        .padding(.horizontal, -4)
                        .padding(.top, -8)
                }
                
                
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await respondToReview()
                        }
                    } label: {
                        Text("Send")
                    }
                    .disabled(replyText.isEmpty)
                    .help(Text("Send the response (⌘-Return)"))
                    .keyboardShortcut(.return, modifiers: .command)
                }
                
                if showError {
                    VStack {
                        Text("Could not send response. Double check that your App Store Connect credentials have the 'Admin' rights attached to it.")
                        Text(errorString)
                        Button {
                            errorString = ""
                            showError = false
                        } label: {
                            Text("hide error")
                        }
                    }
                }
                
                Divider()
                
                suggestionsPicker
                Spacer()
            }
            .padding()
        }
        .clipped()
    }
    
    @StateObject private var translator = DeepL()
    
    func deepLReview() async {
        translator.translate(
            title: review?.attributes?.title ?? "No title",
            body: review?.attributes?.body ?? "No body"
        )
    }
    
    func respondToReview() async {
        guard let review = review else { return }
        
        Task {
            isReplying = true
            
            do {
                let replied = try await reviewManager.replyTo(review: review, with: replyText)
                
                isReplying = false
                if replied {
                    print("replied succesfully")
                    succesfullyReplied = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.getNewReview()
                    }
                } else {
                    print("could not reply")
                    succesfullyReplied = false
                }
            } catch {
                print(error.localizedDescription)
                print(error.localizedDescription)
                let errorCode = (error as NSError).description
                if errorCode.contains("This request is forbidden for security reasons") {
                    errorString = "This request is forbidden for security reasons"
                } else {
                    errorString = "Could not send reply. Not sure why, sorry!"
                }
                
                showError = true
                isError = true
                isReplying = false
            }
            
        }
    }
    
    func title(for review: CustomerReview) -> some View {
        Text(!translator.translatedTitle.isEmpty ? translator.translatedTitle : review.attributes?.title ?? "")
            .font(.system(.title2, design: .rounded))
            .bold()
            .textSelection(.enabled)
    }
    
    func body(for review: CustomerReview) -> some View {
        Text(!translator.translatedBody.isEmpty ? translator.translatedBody : review.attributes?.body ?? "")
            .font(.system(.title3, design: .rounded))
            .textSelection(.enabled)
            .padding(.bottom)
    }
    
    @State var hoveringBody = false
    
    func starsFor(review: CustomerReview) -> some View {
        let realRating = review.attributes?.rating ?? 1
        
        return HStack(spacing: 2) {
            ForEach(0..<realRating, id: \.self) { star in
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
            ForEach(realRating..<5, id: \.self) { star in
                Image(systemName: "star")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
        }
    }
    
    var suggestionsPicker: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Response Suggestions")
                    .font(.system(.body, design: .rounded))
                    .bold()
                
                Spacer()
                
                Button {
                    if appsManager.selectedAppId != "Placeholder" {
                        let suggestion = Suggestion(
                            title: replyText.components(separatedBy: ".").first ?? "New Suggestion",
                            text: replyText,
                            appId: Int(appsManager.selectedAppId ?? "0") ?? 0
                        )
                        suggestions.append(suggestion)
                    }
                } label: {
                    Text("Add Suggestion")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(Color(.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .opacity(replyText.isEmpty ? 0 : 1)
            }
            
            ForEach(suggestions) { suggestion in
                if onlyShowSuggestionsPerApp {
                    if suggestion.appId == Int(appsManager.selectedAppId ?? "") ?? 0 || suggestion.appId == 0 {
                        SuggestionView(
                            suggestion: suggestion,
                            replyText: $replyText,
                            hoveringOnSuggestion: $hoveringOnSuggestion,
                            suggestions: $suggestions
                        )
                    }
                } else {
                    SuggestionView(
                        suggestion: suggestion,
                        replyText: $replyText,
                        hoveringOnSuggestion: $hoveringOnSuggestion,
                        suggestions: $suggestions
                    )
                }
            }
            
        }
    }
    
    func metadata(for review: CustomerReview) -> some View {
        HStack {
            Text(review.attributes?.territory?.flag ?? "")
            Text(review.attributes?.reviewerNickname ?? "")
                .opacity(0.8)
            
            Spacer()
            Text(review.attributes?.createdDate?.formatted(.dateTime.day().month().year()) ?? Date().formatted())
                .opacity(0.8)
        }
        .font(.system(.body, design: .rounded))
    }
    
    
    @State var hoveringOnSuggestion: Suggestion?
    
    
    @State var showTranslate = false
    
    var extraOptions: some View {
        HStack {
            Spacer()
            Button {
                if !showTranslate {
                    translateString = "https://translate.google.com/?sl=auto&tl=en&text=\(review?.attributes?.title ?? "")\n\(review?.attributes?.body ?? "")&op=translate"
                }
                showTranslate.toggle()
            } label: {
                Label(showTranslate ? "Close" : "Translate", systemImage: "globe")
                    .font(.caption)
            }
            
        }
    }
    @ViewBuilder
    var translatorView: some View {
        if showTranslate {
            WebView(urlString: $translateString)
                .frame(height: 500)
        }
    }
    
    @State var translateString = "https://translate.google.com/?sl=en&tl=zh-CN&text=Thanks%20for%20reaching%20out!%20The%20widget%20sometimes%20takes%20a%20while%20to%20appear.%20Can%20you%20send%20an%20email%20to%20jordi%40goodsnooze.com%3F%20Thanks%2C%20Jordi&op=translate"
    
    
    var replyArea: some View {
        
        ZStack(alignment: .topLeading) {
            Color(.controlBackgroundColor)
                .frame(height: 200)
                .onTapGesture {
                    isReplyFocused = true
                }
            
            TextEditor(text: $replyText)
                .focused($isReplyFocused)
                .padding(8)
            //                .frame(height: replyText.count < 30 ? 44 : replyText.count < 110 ? 70 : 110)
                .frame(height: 200)
                .overlay(
                    TextEditor(text: .constant(hoveringOnSuggestion != nil ? hoveringOnSuggestion?.text ?? "" : "Custom Reply"))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .allowsHitTesting(false)
                        .opacity(replyText.isEmpty ? 1 : 0)
                        .frame(height: 200)
                )
                .overlay(
                    HStack {
                        Spacer()
                        Button {
                            translator.translateReply(text: replyText)
                        } label: {
                            Text("Translate")
                        }

                    }
                )
        }
        .font(.system(.title3, design: .rounded))
        .cornerRadius(8)
    }
}


import WebKit

struct WebView: View {
    
    @Binding var urlString: String
    
    var body: some View {
        WebViewWrapper(urlString: urlString)
    }
}

struct WebViewWrapper: NSViewRepresentable {
    
    let urlString: String
    
    func makeNSView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        //        var newURL = urlString
        
        if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let url = URL(string: encoded) {
                let request = URLRequest(url: url)
                nsView.load(request)
            }
        }
    }
}

import Combine

class DeepL: ObservableObject {
    @Published var sourceLanguages = [Language(name: "-", language: "-")]
    @Published var targetLanguages = [Language(name: "-", language: "-")]
    
    @Published var sourceLanguage: Language?
    @Published var targetLanguage: Language?
    
    @Published var detectedSourceLanguage: Language?
    
    @Published var sourceText = ""
    @Published var targetText = ""
    
    @Published var translatedTitle = ""
    @Published var translatedBody = ""
    @Published var translatedReply = ""
    
    @Published var formality = FormalityType.default;
    
    struct Language: Codable, Identifiable, Equatable {
        let id = UUID()
        let name: String
        let language: String
    }
    
    enum LanguagesType: String {
        case source
        case target
    }
    
    enum FormalityType: String {
        case `default`
        case more
        case less
    }
    
    private var subscriptions = Set<AnyCancellable>()
    
    init() {
        print("init deepl")
        self.getLanguages(target: LanguagesType.source, handler: { languages, error in
            guard error == nil && languages != nil else {
                return
            }
            
            DispatchQueue.main.async {
                self.sourceLanguages = languages!
                self.sourceLanguage = self.findLanguage(array: languages!, language: "EN")  // TODO: Default
            }
        })
        
        self.getLanguages(target: LanguagesType.target, handler: { languages, error in
            guard error == nil && languages != nil else {
                return
            }
            
            DispatchQueue.main.async {
                self.targetLanguages = languages!
                self.targetLanguage = self.findLanguage(array: languages!, language: "NL") // TODO: Default
            }
        })
        
//        $sourceText
//            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
//            .sink(receiveValue: { value in
//                self.translate(text: value)
//            })
//            .store(in: &subscriptions)
    }
    
    private func getLanguages(target: LanguagesType, handler: @escaping ([Language]?, Error?) -> Void) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api-free.deepl.com"
        components.path = "/v2/languages"
        components.queryItems = [
            URLQueryItem(name: "auth_key", value: "cd8101dc-b9d7-acd9-f310-1cf89e8186de:fx"),
            URLQueryItem(name: "type", value: target.rawValue),
        ]
        
        URLSession.shared.dataTask(with: components.url!, completionHandler: { data, _, _ in
            guard data != nil else {
                return
            }
            
            do {
                if let response = try JSONDecoder().decode([Language]?.self, from: data!) {
                    handler(response, nil)
                }
            } catch let error {
                handler(nil, error)
            }
        }).resume()
    }
    
    private func findLanguage(array: [Language], language: String) -> Language? {
        if let index = array.firstIndex(where: { $0.language == language }) {
            return array[index]
        }
        return nil
    }
    
    func translate(title: String, body: String) {
        translateTitle(text: title)
        translateBody(text: body)
    }
    
    func translateTitle(text: String) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api-free.deepl.com"
        components.path = "/v2/translate"
        components.queryItems = [
            URLQueryItem(name: "auth_key", value: "cd8101dc-b9d7-acd9-f310-1cf89e8186de:fx"),
            // TODO: What is these are nil
//            URLQueryItem(name: "source_lang", value: "NL"), // TODO: Default
            URLQueryItem(name: "target_lang", value: "EN"), // TODO: Default
            URLQueryItem(name: "formality", value: self.formality.rawValue),
            URLQueryItem(name: "text", value: text)
        ]
        
        URLSession.shared.dataTask(with: components.url!, completionHandler: { data, _, _ in
            guard data != nil else {
                return
            }
            
            struct Response: Codable {
                let translations: [Translation]
            }
            
            struct Translation: Codable {
                let detectedSourceLanguage: String?
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case detectedSourceLanguage = "detected_source_language"
                    case text
                }
            }
            
            if let response = try? JSONDecoder().decode(Response?.self, from: data!) {
                DispatchQueue.main.async {
                    if let language = response.translations[0].detectedSourceLanguage {
                        
                        if let foundLanguage = self.findLanguage(array: self.sourceLanguages, language: language) {
                            if foundLanguage.language != self.sourceLanguage!.language {
                                self.sourceLanguage = self.findLanguage(array: self.sourceLanguages, language: language) // TODO: Default
                            }
                        }
                    }
                    
                    self.translatedTitle = response.translations[0].text
                    
                }
            }
        }).resume()
    }
    
    func translateBody(text: String) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api-free.deepl.com"
        components.path = "/v2/translate"
        components.queryItems = [
            URLQueryItem(name: "auth_key", value: "cd8101dc-b9d7-acd9-f310-1cf89e8186de:fx"),
            // TODO: What is these are nil
//            URLQueryItem(name: "source_lang", value: "NL"), // TODO: Default
            URLQueryItem(name: "target_lang", value: "EN"), // TODO: Default
            URLQueryItem(name: "formality", value: self.formality.rawValue),
            URLQueryItem(name: "text", value: text)
        ]
        
        URLSession.shared.dataTask(with: components.url!, completionHandler: { data, _, _ in
            guard data != nil else {
                return
            }
            
            struct Response: Codable {
                let translations: [Translation]
            }
            
            struct Translation: Codable {
                let detectedSourceLanguage: String?
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case detectedSourceLanguage = "detected_source_language"
                    case text
                }
            }
            
            if let response = try? JSONDecoder().decode(Response?.self, from: data!) {
                DispatchQueue.main.async {
                    if let language = response.translations[0].detectedSourceLanguage {
                        if let foundLanguage = self.findLanguage(array: self.sourceLanguages, language: language) {
                            if foundLanguage.language != self.sourceLanguage!.language {
                                self.sourceLanguage = self.findLanguage(array: self.sourceLanguages, language: language) // TODO: Default
                            }
                            self.detectedSourceLanguage = foundLanguage
                            
                        }
                    }
                    
                    self.translatedBody = response.translations[0].text
                }
            }
        }).resume()
    }
    
    func translateReply(text: String) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api-free.deepl.com"
        components.path = "/v2/translate"
        components.queryItems = [
            URLQueryItem(name: "auth_key", value: "cd8101dc-b9d7-acd9-f310-1cf89e8186de:fx"),
            // TODO: What is these are nil
//            URLQueryItem(name: "source_lang", value: "NL"), // TODO: Default
            URLQueryItem(name: "target_lang", value: detectedSourceLanguage?.language ?? "EN"), // TODO: Default
            URLQueryItem(name: "formality", value: self.formality.rawValue),
            URLQueryItem(name: "text", value: text)
        ]
        
        URLSession.shared.dataTask(with: components.url!, completionHandler: { data, _, _ in
            guard data != nil else {
                return
            }
            
            struct Response: Codable {
                let translations: [Translation]
            }
            
            struct Translation: Codable {
                let detectedSourceLanguage: String?
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case detectedSourceLanguage = "detected_source_language"
                    case text
                }
            }
            
            if let response = try? JSONDecoder().decode(Response?.self, from: data!) {
                DispatchQueue.main.async {
                    if let language = response.translations[0].detectedSourceLanguage {
                        if let foundLanguage = self.findLanguage(array: self.sourceLanguages, language: language) {
                            if foundLanguage.language != self.sourceLanguage!.language {
                                self.sourceLanguage = self.findLanguage(array: self.sourceLanguages, language: language) // TODO: Default
                            }
//                            self.detectedSourceLanguage = foundLanguage
                        }
                    }
                    
                    self.translatedReply = response.translations[0].text
                    print(response.translations[0].text)
                }
            }
        }).resume()
    }
}
