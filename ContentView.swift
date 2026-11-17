import SwiftUI
import UIKit

enum ArtStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case hyperRealistic = "Hyper Realistic"
    case photorealistic = "Photorealistic"
    case anime = "Anime"
    case furry = "Furry"
    case watercolor = "Watercolor"
    case cyberpunk = "Cyberpunk"
    case oilPainting = "Oil Painting"
    
    var id: String { self.rawValue }
    
    var promptSuffix: String {
        switch self {
        case .none:
            return ""
        case .hyperRealistic:
            return ", hyperrealistic photograph, raw candid photo, 35mm lens, f/1.8, natural skin texture, pores, realistic lighting, ultra detailed, sharp focus, shot on Sony A7R IV"
        case .photorealistic:
            return ", photorealistic, 8k resolution, highly detailed, cinematic lighting"
        case .anime:
            return ", anime style, studio ghibli inspired, vibrant colors, crisp lineart"
        case .furry:
            return ", furry art style, anthropomorphic character, vibrant fur texture, expressive eyes, detailed digital illustration"
        case .watercolor:
            return ", watercolor painting, soft brush strokes, artistic, pastel washes"
        case .cyberpunk:
            return ", cyberpunk aesthetic, neon lights, futuristic city, sci-fi, moody atmosphere"
        case .oilPainting:
            return ", classic oil painting, textured canvas, rich brushstrokes, masterpiece"
        }
    }
}

enum AspectRatioOption: String, CaseIterable, Identifiable {
    case square = "Square (1:1)"
    case portrait = "Portrait (3:4)"
    case landscape = "Landscape (4:3)"
    
    var id: String { self.rawValue }
    
    func dimensions(baseSize: Double) -> (width: Int, height: Int) {
        let base = Int(baseSize.rounded())
        switch self {
        case .square:
            return (base, base)
        case .portrait:
            let w = Int((Double(base) * 0.75).rounded())
            return (max(256, w), base)
        case .landscape:
            let h = Int((Double(base) * 0.75).rounded())
            return (base, max(256, h))
        }
    }
}

enum ActiveInputField {
    case prompt
    case negativePrompt
}

struct ContentView: View {
    @AppStorage("pollinationsAPIKey") private var pollinationsAPIKey: String = ""
    
    @State private var prompt: String = ""
    @State private var negativePrompt: String = "casual clothes, modern clothing, plain t-shirt, jeans"
    @State private var selectedStyle: ArtStyle = .none
    @State private var selectedRatio: AspectRatioOption = .square
    @State private var baseResolution: Double = 512
    @State private var loadedUIImage: UIImage? = nil
    @State private var isGenerating: Bool = false
    @State private var generationError: String? = nil
    @State private var saveMessage: String? = nil
    @State private var showingSaveAlert: Bool = false
    @State private var showAPIKeyField: Bool = false
    @State private var activeSaver: ImageSaver? = nil
    
    // Seed & Exact Prompt Controls
    @State private var currentSeed: Int = Int.random(in: 1...999999)
    @State private var isSeedLocked: Bool = false
    @State private var isEnhanceEnabled: Bool = false
    
    // Safety & Privacy Controls
    @State private var isSafeFilterEnabled: Bool = false
    @State private var isPrivateMode: Bool = true
    
    // Pull-Out Custom Keyboard State
    @State private var isKeyboardOpen: Bool = false
    @State private var activeField: ActiveInputField = .prompt
    
    var currentDimensions: (width: Int, height: Int) {
        selectedRatio.dimensions(baseSize: baseResolution)
    }
    
    private var activeTextBinding: Binding<String> {
        switch activeField {
        case .prompt:
            return $prompt
        case .negativePrompt:
            return $negativePrompt
        }
    }
    
    private var activeFieldTitle: String {
        switch activeField {
        case .prompt:
            return "Editing Prompt"
        case .negativePrompt:
            return "Editing Negative Prompt"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Art Generator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        imageDisplaySection
                        actionButtonsSection
                        promptInputSection
                        negativePromptInputSection
                        artStyleSection
                        aspectRatioSection
                        resolutionSection
                        seedControlSection
                        privacyAndSafetySection
                        apiKeySection
                        generateButtonSection
                    }
                    .padding(.vertical)
                    .padding(.bottom, isKeyboardOpen ? 20 : 70)
                }
                
                if !isKeyboardOpen {
                    floatingKeyboardButton
                }
            }
            
            if isKeyboardOpen {
                PullOutKeyboardView(
                    text: activeTextBinding,
                    fieldTitle: activeFieldTitle,
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isKeyboardOpen = false
                        }
                    }
                )
            }
        }
        .alert("Photo Library", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveMessage ?? "")
        }
    }
    
    // MARK: - Subviews
    
    private var imageDisplaySection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 320)
            
            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Generating \(currentDimensions.width)x\(currentDimensions.height) image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let uiImage = loadedUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
            } else if let errorText = generationError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Tap Prompt or Open Keyboard to create art")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        if let uiImage = loadedUIImage {
            HStack(spacing: 12) {
                Button(action: saveImageToPhotos) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save to Photos")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                ShareLink(
                    item: Image(uiImage: uiImage),
                    preview: SharePreview("AI Generated Art", image: Image(uiImage: uiImage))
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var promptInputSection: some View {
        let isFocused = isKeyboardOpen && activeField == .prompt
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Prompt")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        if isFocused {
                            isKeyboardOpen = false
                        } else {
                            activeField = .prompt
                            isKeyboardOpen = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isFocused ? "keyboard.chevron.compact.down" : "keyboard")
                        Text(isFocused ? "Hide Keyboard" : "Edit Prompt")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(isFocused ? .blue : .secondary)
                    .padding(.top, 2)
                
                Text(prompt.isEmpty ? "Tap here to describe outfit, pose, and scene..." : (isFocused ? prompt + "▎" : prompt))
                    .foregroundColor(prompt.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    activeField = .prompt
                    isKeyboardOpen = true
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1.5)
            )
            
            if !prompt.isEmpty {
                HStack {
                    Spacer()
                    Button("Clear Prompt") {
                        prompt = ""
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var negativePromptInputSection: some View {
        let isFocused = isKeyboardOpen && activeField == .negativePrompt
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Negative Prompt (Avoid)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        if isFocused {
                            isKeyboardOpen = false
                        } else {
                            activeField = .negativePrompt
                            isKeyboardOpen = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isFocused ? "keyboard.chevron.compact.down" : "keyboard")
                        Text(isFocused ? "Hide Keyboard" : "Edit Negative")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
            }
            
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "nosign")
                    .foregroundColor(isFocused ? .orange : .secondary)
                    .padding(.top, 2)
                
                Text(negativePrompt.isEmpty ? "Tap to specify elements to exclude..." : (isFocused ? negativePrompt + "▎" : negativePrompt))
                    .foregroundColor(negativePrompt.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    activeField = .negativePrompt
                    isKeyboardOpen = true
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1.5)
            )
            
            if !negativePrompt.isEmpty {
                HStack {
                    Spacer()
                    Button("Clear Negative") {
                        negativePrompt = ""
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var artStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Art Style")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text(selectedStyle == .none ? "Exact prompt (no suffix)" : "Appends style keywords")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ArtStyle.allCases) { style in
                        Button(action: {
                            selectedStyle = style
                        }) {
                            Text(style.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedStyle == style ? Color.blue : Color.gray.opacity(0.15))
                                .foregroundColor(selectedStyle == style ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var aspectRatioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aspect Ratio")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Picker("Aspect Ratio", selection: $selectedRatio) {
                ForEach(AspectRatioOption.allCases) { ratio in
                    Text(ratio.rawValue).tag(ratio)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }
    
    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resolution")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(currentDimensions.width) × \(currentDimensions.height) px")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .monospacedDigit()
            }
            
            Slider(
                value: Binding(
                    get: { baseResolution },
                    set: { newValue in
                        baseResolution = (newValue / 64.0).rounded() * 64.0
                    }
                ),
                in: 256...1024,
                step: 64
            )
            .tint(.blue)
            
            HStack {
                Text("256px (Fast / Soft)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("1024px (Sharp / Detailed)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var seedControlSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Seed: \(currentSeed)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(isSeedLocked ? "Locked (reproduces identical outcome)" : "Randomizes on each generation")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                currentSeed = Int.random(in: 1...999999)
            }) {
                Image(systemName: "dice")
                    .padding(8)
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }
            
            Toggle("Lock Seed", isOn: $isSeedLocked)
                .labelsHidden()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var privacyAndSafetySection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $isEnhanceEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Prompt Enhancement")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(isEnhanceEnabled ? "AI expands your prompt with extra detail" : "Off (follows your exact prompt text)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Toggle(isOn: $isSafeFilterEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safe Mode Filter")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Enable Pollinations server-side content filter")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Toggle(isOn: $isPrivateMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Private Generation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Keep generated images off public feeds")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    showAPIKeyField.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "key.fill")
                    Text("API Key Settings")
                    Spacer()
                    Image(systemName: showAPIKeyField ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            }
            
            if showAPIKeyField {
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Enter Pollinations Secret Key (sk_...)", text: $pollinationsAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if pollinationsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("pk_") {
                        Text("Warning: Public keys (pk_) are for OAuth flows. Use a Secret Key (sk_) from enter.pollinations.ai to avoid 401/402 errors.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var generateButtonSection: some View {
        let isDisabled = prompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isKeyboardOpen = false
            }
            generateImage()
        }) {
            HStack {
                Image(systemName: isGenerating ? "hourglass" : "sparkles")
                Text(isGenerating ? "Generating..." : "Generate Image")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDisabled)
        .padding(.horizontal)
    }
    
    private var floatingKeyboardButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isKeyboardOpen = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.headline)
                Text("Keyboard")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Logic Helpers
    
    func generateImage() {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }
        
        loadedUIImage = nil
        generationError = nil
        isGenerating = true
        
        let fullPrompt = trimmedPrompt + selectedStyle.promptSuffix
        
        var allowedChars = CharacterSet.urlPathAllowed
        allowedChars.remove(charactersIn: "/?")
        
        guard let encodedPrompt = fullPrompt.addingPercentEncoding(withAllowedCharacters: allowedChars) else {
            isGenerating = false
            generationError = "Invalid characters in prompt."
            return
        }
        
        if !isSeedLocked {
            currentSeed = Int.random(in: 1...999999)
        }
        let dims = currentDimensions
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "gen.pollinations.ai"
        components.percentEncodedPath = "/image/\(encodedPrompt)"
        
        var queryItems = [
            URLQueryItem(name: "model", value: "flux"),
            URLQueryItem(name: "seed", value: "\(currentSeed)"),
            URLQueryItem(name: "width", value: "\(dims.width)"),
            URLQueryItem(name: "height", value: "\(dims.height)"),
            URLQueryItem(name: "nologo", value: "true"),
            URLQueryItem(name: "enhance", value: isEnhanceEnabled ? "true" : "false"),
            URLQueryItem(name: "safe", value: isSafeFilterEnabled ? "true" : "false"),
            URLQueryItem(name: "private", value: isPrivateMode ? "true" : "false")
        ]
        
        let trimmedNegative = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNegative.isEmpty {
            queryItems.append(URLQueryItem(name: "negative", value: trimmedNegative))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            isGenerating = false
            generationError = "Could not create request URL."
            return
        }
        
        var request = URLRequest(url: url)
        let cleanKey = pollinationsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isGenerating = false
                
                if let error = error {
                    self.generationError = "Network error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    let serverBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let parsedMessage = Self.extractAPIErrorMessage(from: data)
                    
                    switch httpResponse.statusCode {
                    case 401:
                        self.generationError = "Error 401: Unauthorized. Please check your Secret API Key (sk_...) in API Key Settings."
                    case 402:
                        if cleanKey.isEmpty {
                            self.generationError = "Error 402: Payment / API Key Required. Add a valid Pollinations Secret Key (sk_...) in API Key Settings or check your Pollen balance at enter.pollinations.ai."
                        } else if let detail = parsedMessage {
                            self.generationError = "Error 402: Insufficient Pollen or tier limit reached (\(detail)). Check your balance at enter.pollinations.ai."
                        } else {
                            self.generationError = "Error 402: Insufficient Pollen or tier limit reached. Top up your balance or complete quests at enter.pollinations.ai."
                        }
                    default:
                        if let detail = parsedMessage {
                            self.generationError = "Error \(httpResponse.statusCode): \(detail)"
                        } else if !serverBody.isEmpty {
                            self.generationError = "Error \(httpResponse.statusCode): \(serverBody)"
                        } else {
                            self.generationError = "Server returned error code \(httpResponse.statusCode). Try again."
                        }
                    }
                    return
                }
                
                guard let data = data, let uiImage = UIImage(data: data) else {
                    self.generationError = "Failed to decode image data. Try regenerating."
                    return
                }
                
                self.loadedUIImage = uiImage
            }
        }.resume()
    }
    
    private static func extractAPIErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String, !message.isEmpty {
            return message
        }
        if let errorStr = json["error"] as? String, !errorStr.isEmpty {
            return errorStr
        }
        return nil
    }
    
    func saveImageToPhotos() {
        guard let image = loadedUIImage else { return }
        let saver = ImageSaver { error in
            if let error = error {
                saveMessage = "Failed to save: \(error.localizedDescription). Make sure 'Photo Library Additions' is enabled in Info.plist."
            } else {
                saveMessage = "Image saved to your Photos!"
            }
            showingSaveAlert = true
            activeSaver = nil
        }
        activeSaver = saver
        saver.writeToPhotoAlbum(image: image)
    }
}

// MARK: - Custom Pull-Out QWERTY Keyboard View

struct PullOutKeyboardView: View {
    @Binding var text: String
    let fieldTitle: String
    let onClose: () -> Void
    
    @State private var isShifted: Bool = true
    @State private var isNumbersMode: Bool = false
    
    private let row1Letters = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let row2Letters = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let row3Letters = ["z", "x", "c", "v", "b", "n", "m"]
    
    private let row1Numbers = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let row2Numbers = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
    private let row3Numbers = [".", ",", "?", "!", "'", "+", "="]
    
    var body: some View {
        VStack(spacing: 8) {
            toolbarHeader
            
            VStack(spacing: 8) {
                firstKeyRow
                secondKeyRow
                thirdKeyRow
                bottomControlRow
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .background(Color(UIColor.systemGray5))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.35)),
            alignment: .top
        )
    }
    
    private var toolbarHeader: some View {
        HStack(spacing: 8) {
            Text(fieldTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: pasteFromClipboard) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard.chevron.compact.down")
                    Text("Done")
                }
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    private var firstKeyRow: some View {
        let keys = isNumbersMode ? row1Numbers : row1Letters
        return HStack(spacing: 5) {
            ForEach(keys, id: \.self) { key in
                keyButton(for: key)
            }
        }
    }
    
    private var secondKeyRow: some View {
        let keys = isNumbersMode ? row2Numbers : row2Letters
        return HStack(spacing: 5) {
            if !isNumbersMode { Spacer(minLength: 10) }
            ForEach(keys, id: \.self) { key in
                keyButton(for: key)
            }
            if !isNumbersMode { Spacer(minLength: 10) }
        }
    }
    
    private var thirdKeyRow: some View {
        let keys = isNumbersMode ? row3Numbers : row3Letters
        return HStack(spacing: 5) {
            if !isNumbersMode {
                Button(action: { isShifted.toggle() }) {
                    Image(systemName: isShifted ? "shift.fill" : "shift")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 42)
                        .background(isShifted ? Color.white : Color(UIColor.systemGray3))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                }
            }
            
            ForEach(keys, id: \.self) { key in
                keyButton(for: key)
            }
            
            Button(action: handleBackspace) {
                Image(systemName: "delete.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 42)
                    .background(Color(UIColor.systemGray3))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
        }
    }
    
    private var bottomControlRow: some View {
        HStack(spacing: 6) {
            Button(action: { isNumbersMode.toggle() }) {
                Text(isNumbersMode ? "ABC" : "123")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 64, height: 42)
                    .background(Color(UIColor.systemGray3))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            
            Button(action: { appendCharacter(",") }) {
                Text(",")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 40, height: 42)
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            
            Button(action: { appendCharacter(" ") }) {
                Text("space")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            
            Button(action: { appendCharacter(".") }) {
                Text(".")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 40, height: 42)
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
            
            Button(action: onClose) {
                Text("Return")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 72, height: 42)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
            }
        }
    }
    
    private func keyButton(for rawKey: String) -> some View {
        let displayChar = (!isNumbersMode && isShifted) ? rawKey.uppercased() : rawKey
        return Button(action: {
            appendCharacter(displayChar)
            if !isNumbersMode && isShifted {
                isShifted = false
            }
        }) {
            Text(displayChar)
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(UIColor.systemBackground))
                .foregroundColor(.primary)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        }
    }
    
    private func appendCharacter(_ char: String) {
        text.append(char)
        if text.hasSuffix(". ") {
            isShifted = true
        }
    }
    
    private func handleBackspace() {
        if !text.isEmpty {
            text.removeLast()
            if text.isEmpty {
                isShifted = true
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string {
            text.append(pasted)
        }
    }
}

class ImageSaver: NSObject {
    var completion: (Error?) -> Void
    
    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error)
    }
}
