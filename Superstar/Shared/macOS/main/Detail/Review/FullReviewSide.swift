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
//            .frame(width: 280)
        }
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
        .toolbar(content: {
            ToolbarItem(placement: .automatic) {
                Button {
                    getNewReview()
                } label: {
                    Text("Skip")
                }
                .opacity(review == nil ? 0 : 1)
            }
            ToolbarItem(placement: .automatic) {
                Spacer()
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await respondToReview()
                    }
                } label: {
                    Text("Send")
                }
                .opacity(review == nil ? 0 : 1)
                .disabled(reviewManager.replyText.isEmpty)
            }
        })
        .onChange(of: review) { newValue in
//            reviewManager.replyText = ""
            isReplying = false
            succesfullyReplied = false
            isReplyFocused = true
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
    
    func reviewView(review: CustomerReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    starsFor(review: review)
                    title(for: review)
                    metadata(for: review)
                }
                body(for: review)

                replyArea
                    .padding(.horizontal, -4)
                    .padding(.top, -8)
                
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await respondToReview()
                        }
                    } label: {
                        Text("Send")
                    }
                    .disabled(reviewManager.replyText.isEmpty)
                }
                
//                extraOptions
//                translatorView
                
                suggestionsPicker
                Spacer()
            }
            .padding()
        }
        .clipped()
    }
    
    func respondToReview() async {
        guard let review = review else { return }

        Task {
            isReplying = true
            let replied = await reviewManager.replyTo(review: review, with: reviewManager.replyText)
//            let replied = true
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
        }
    }
    
    func title(for review: CustomerReview) -> some View {
        Text(review.attributes?.title ?? "")
            .font(.system(.title2, design: .rounded))
            .bold()
            .textSelection(.enabled)
    }
    
    func body(for review: CustomerReview) -> some View {
        Text(review.attributes?.body ?? "")
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
    
    @State var translateString = "https://translate.google.com/?sl=en&tl=zh-CN&text=Thanks%20for%20reaching%20out!%20The%20widget%20sometimes%20takes%20a%20while%20to%20appear.%20Can%20you%20send%20an%20email%20to%20jordi%40goodsnooze.com%3F%20Thanks%2C%20Jordi&op=translate"
    
    @State var showTranslate = false
    
    var extraOptions: some View {
        HStack {
            Button {
                if !showTranslate {
                    translateString = "https://translate.google.com/?sl=auto&tl=en&text=\(review?.attributes?.body ?? "")&op=translate"
                }
                showTranslate.toggle()
            } label: {
                Text(showTranslate ? "Close Translation" : "Open Translation")
            }
            
            Spacer()
            
//            Button {
//                print(appsManager.selectedAppId)
//                if appsManager.selectedApp.id != "Placeholder" {
//                    let suggestion = Suggestion(title: "New Suggestion", text: replyText, appId: Int(appsManager.selectedAppId ?? "0") ?? 0)
//                    suggestions.append(suggestion)
//                }
//            } label: {
//                Text("Save as Suggestion")
//            }

        }
    }
    @ViewBuilder
    var translatorView: some View {
        if showTranslate {
            WebView(urlString: $translateString)
                .frame(height: 500)
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
                        let suggestion = Suggestion(title: "New Suggestion", text: reviewManager.replyText, appId: Int(appsManager.selectedAppId ?? "0") ?? 0)
                        suggestions.append(suggestion)
                    }
                } label: {
                    HStack {
                        Text("Add Suggestion")
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.controlBackgroundColor))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            
            ForEach(suggestions) { suggestion in
                Button {
                    reviewManager.replyText = suggestion.text

                    // TODO: show next review
                    // TODO: auto reply
//                    if autoReply {
//                        print("we should automatically sent it now")
//                        Task {
//                            await respondToReview()
//                        }
//                    } else {
//                        showReplyField = true
//                    }
                } label: {
                    HStack {
                        if let url = appsManager.imageURLfor(appId: "\(suggestion.appId)") {
                            CacheAsyncImage(url: url, scale: 2) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .clipped()
                                case .failure(let _):
                                    Text("E")
                                case .empty:
                                    Color.gray.opacity(0.05)
                                @unknown default:
                                    // AsyncImagePhase is not marked as @frozen.
                                    // We need to support new cases in the future.
                                    Image(systemName: "questionmark")
                                }
                            }
                            .frame(width: 18, height: 18)
                        }
                        
//                        Text(appsManager.appNameFor(appId: "\(suggestion.appId)"))
                        Text(suggestion.title.capitalized)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.controlBackgroundColor))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
//            Menu {
//                ForEach(suggestions) {  suggestion in
//                    Button {
//                        replyText = suggestion.text
//
//    //                    if autoReply {
//    //                        print("we should automatically sent it now")
//    //                        Task {
//    //                            await respondToReview()
//    //                        }
//    //                    } else {
//                            showReplyField = true
//    //                    }
//                    } label: {
//                        Text(suggestion.title.capitalized)
//                            .padding(.vertical, 6)
//                            .padding(.horizontal, 12)
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(12)
//                    }
//                    .buttonStyle(.plain)
//                }
//            } label: {
//                Text("Suggestions")
//            }
//            .menuStyle(.borderlessButton)
//            .frame(width: 110)
//            .padding(.vertical, 4)
//            .padding(.horizontal, 6)
//            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.secondary.opacity(0.1)))
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

    var replyArea: some View {

        ZStack(alignment: .topLeading) {
            Color(.controlBackgroundColor)
                .frame(height: 200)
                .onTapGesture {
                    isReplyFocused = true
                }

            TextEditor(text: $reviewManager.replyText)
                .focused($isReplyFocused)
                .padding(8)
//                .frame(height: replyText.count < 30 ? 44 : replyText.count < 110 ? 70 : 110)
                .frame(height: 200)
                .overlay(
                    TextEditor(text: .constant("Custom Reply"))
                        .opacity(0.4)
                        .padding(8)
                        .allowsHitTesting(false)
                        .opacity(reviewManager.replyText.isEmpty ? 1 : 0)
                        .frame(height: 200)
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

//extension String {
//    var URLEncoded:String {
//
//        let unreservedChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
//        let unreservedCharsSet: CharacterSet = CharacterSet(charactersIn: unreservedChars)
//        let encodedString = self.addingPercentEncoding(withAllowedCharacters: unreservedCharsSet)!
//        return encodedString
//    }
//}
