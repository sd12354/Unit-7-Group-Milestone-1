import SwiftUI
#if canImport(GoogleSignInSwift)
import GoogleSignInSwift
#endif

/// Email + password sign-in, links to Register, optional Google / phone, forgot password.
struct LoginView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var animateLoginArrow = false
    @State private var showPassword = false
    @State private var showPhoneSection = false
    @State private var showRegisterScreen = false
    @State private var phoneDialCountry = DialCountry.unitedStates
    @State private var phoneNationalFormatted = ""
    @State private var localMessage: String?
    @State private var localMessageIsError = true
    @FocusState private var isEmailFieldFocused: Bool
    @FocusState private var isPasswordFieldFocused: Bool
    @FocusState private var isPhoneFieldFocused: Bool
    /// On white inputs, SecureField bullets read as neutral gray; match email text to that tone (avoids blue-tinted hex).
    private let inputTextColor = Color(white: 0.38)

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Image("StudySyncLogoTransparent")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .padding(.bottom, 2)
                        Text("StudySync")
                            .font(AppTheme.titleFont)
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("Find your study crew")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .padding(.top, 76)

                    VStack(alignment: .leading, spacing: 8) {
                    Label("Email", systemImage: "envelope.fill")
                        .font(AppTheme.bodyFont.weight(.medium))
                        .foregroundStyle(.white)

                        TextField(
                            "",
                            text: $email,
                        prompt: Text("johndoe@gmail.com").foregroundStyle(inputTextColor.opacity(0.65))
                        )
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(inputTextColor)
                            .tint(inputTextColor)
                            .focused($isEmailFieldFocused)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isEmailFieldFocused ? AppTheme.accent : AppTheme.primary.opacity(0.55), lineWidth: isEmailFieldFocused ? 2.5 : 1.5)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                    Label("Password", systemImage: "lock.fill")
                        .font(AppTheme.bodyFont.weight(.medium))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Group {
                            if showPassword {
                                TextField(
                                    "",
                                    text: $password,
                                    prompt: Text("••••••••").foregroundStyle(inputTextColor.opacity(0.65))
                                )
                            } else {
                                SecureField(
                                    "",
                                    text: $password,
                                    prompt: Text("••••••••").foregroundStyle(inputTextColor.opacity(0.65))
                                )
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(inputTextColor)
                        .tint(inputTextColor)
                        .focused($isPasswordFieldFocused)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(AppTheme.primary.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isPasswordFieldFocused ? AppTheme.accent : AppTheme.primary.opacity(0.55), lineWidth: isPasswordFieldFocused ? 2.5 : 1.5)
                    )
                    }

                    Button {
                        Task { await handleEmailLogin() }
                    } label: {
                    HStack(spacing: 8) {
                        Text("Log In")
                            .font(AppTheme.labelFont)

                        if shouldShowLoginArrow {
                            Image(systemName: "arrow.right")
                                .font(.headline.weight(.bold))
                                .offset(x: animateLoginArrow ? 3 : -1)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .animation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                    value: animateLoginArrow
                                )
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                .animation(.easeOut(duration: 0.25), value: shouldShowLoginArrow)
                    .appPressEffect()
                    .disabled(authViewModel.isLoading)

                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.white.opacity(0.9))
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 0)

                    Button {
                        showRegisterScreen = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Create account")
                                .font(AppTheme.labelFont)
                        }
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(AppTheme.primary.opacity(0.8), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .appPressEffect()

                    providerButtons

                    if showPhoneSection {
                        phoneSection
                            .id("phoneAuthSection")
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    messageBlock

                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Button {
                        Task { await handleForgotPassword() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle")
                            Text("Forgot password?")
                                .underline(true, color: .white)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                    .foregroundStyle(.white)
                }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 6)
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: showPhoneSection) { _, isShown in
                guard isShown else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("phoneAuthSection", anchor: .center)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isPhoneFieldFocused = true
                }
            }
            .onAppear {
                animateLoginArrow = true
            }
            .navigationDestination(isPresented: $showRegisterScreen) {
                RegisterView()
                    .environmentObject(authViewModel)
            }
        }
    }

    private var shouldShowLoginArrow: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    @ViewBuilder
    private var messageBlock: some View {
        if let notice = authViewModel.transientNotice, !notice.isEmpty {
            Text(notice)
                .font(.footnote)
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let message = localMessage, !message.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundStyle(localMessageIsError ? AppTheme.error : AppTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = authViewModel.errorMessage, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(AppTheme.error)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var providerButtons: some View {
        VStack(spacing: 8) {
            googleSignInButton

            Button {
                withAnimation {
                    showPhoneSection = true
                    phoneDialCountry = .unitedStates
                    phoneNationalFormatted = ""
                }
                localMessageIsError = false
                localMessage = nil
            } label: {
                Label(showPhoneSection ? "Phone login ready" : "Continue with Phone", systemImage: "phone")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .font(AppTheme.bodyFont.weight(.semibold))
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .appPressEffect()
        }
    }

    @ViewBuilder
    private var googleSignInButton: some View {
        Button {
            Task { await authViewModel.signInWithGoogle() }
        } label: {
            Label("Continue with Google", systemImage: "globe")
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .font(AppTheme.bodyFont.weight(.semibold))
                .background(Color(hex: "2D3A65"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: AppTheme.primary.opacity(0.35), radius: 6, y: 3)
        .appPressEffect()
    }

    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "phone.badge.checkmark")
                    .foregroundStyle(.white)
                Text("Phone Number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(DialCountry.common) { country in
                        Button {
                            phoneDialCountry = country
                        } label: {
                            HStack {
                                Text("\(country.flag) \(country.name)  \(country.dialCode)")
                                if country.id == phoneDialCountry.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(phoneDialCountry.flag)
                        Text(phoneDialCountry.dialCode)
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(inputTextColor)
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .frame(minWidth: 88)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.45), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Country code")

                TextField(
                    phoneDialCountry.usesNANP ? "(555) 123-4567" : "Phone number",
                    text: $phoneNationalFormatted,
                    prompt: Text(phoneDialCountry.usesNANP ? "(555) 123-4567" : "e.g. 7700 900123")
                        .foregroundStyle(inputTextColor.opacity(0.55))
                )
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .foregroundStyle(inputTextColor)
                .tint(inputTextColor)
                .focused($isPhoneFieldFocused)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.45), lineWidth: 1)
                )
                .onChange(of: phoneNationalFormatted) { _, new in
                    let formatted = Self.applyNationalFormat(new, country: phoneDialCountry)
                    if formatted != new {
                        phoneNationalFormatted = formatted
                    }
                }
                .onChange(of: phoneDialCountry) { _, country in
                    let digits = phoneNationalFormatted.filter(\.isNumber)
                    let formatted = Self.applyNationalFormat(digits, country: country)
                    if formatted != phoneNationalFormatted {
                        phoneNationalFormatted = formatted
                    }
                }
            }

            Button("Send Code") {
                let digits = phoneNationalFormatted.filter(\.isNumber)
                authViewModel.phoneNumber = phoneDialCountry.dialCode + digits
                Task { await authViewModel.sendPhoneVerificationCode() }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .appPressEffect()

            Text("Choose your country code, enter your number, then tap Send Code.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            if authViewModel.isPhoneCodeSent {
                TextField("Verification code", text: $authViewModel.phoneVerificationCode)
                    .keyboardType(.numberPad)
                    .foregroundStyle(inputTextColor)
                    .tint(inputTextColor)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.45), lineWidth: 1)
                    )

                Button("Verify and Sign In") {
                    Task { await authViewModel.verifyPhoneCode() }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .appPressEffect()
            }
        }
    }

    private func handleEmailLogin() async {
        localMessage = nil
        authViewModel.clearError()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter your email."
            return
        }
        guard !password.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter your password."
            return
        }

        await authViewModel.signInWithEmail(email: trimmedEmail, password: password)
        // On success, `AuthGateView` shows `ContentView` when `isSignedIn` becomes true.
    }

    private func handleForgotPassword() async {
        localMessage = nil
        authViewModel.clearError()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localMessageIsError = true
            localMessage = "Enter your email above, then tap Forgot password."
            return
        }

        await authViewModel.sendPasswordReset(email: trimmedEmail)
        if authViewModel.errorMessage == nil {
            localMessageIsError = false
            localMessage = nil
        }
    }
}

// MARK: - Phone dial countries & formatting

private extension LoginView {
    struct DialCountry: Identifiable, Hashable {
        let id: String
        let flag: String
        let name: String
        let dialCode: String

        var usesNANP: Bool { dialCode == "+1" }

        static let unitedStates = DialCountry(id: "US", flag: "🇺🇸", name: "United States", dialCode: "+1")

        static let common: [DialCountry] = [
            .unitedStates,
            DialCountry(id: "CA", flag: "🇨🇦", name: "Canada", dialCode: "+1"),
            DialCountry(id: "GB", flag: "🇬🇧", name: "United Kingdom", dialCode: "+44"),
            DialCountry(id: "IN", flag: "🇮🇳", name: "India", dialCode: "+91"),
            DialCountry(id: "AU", flag: "🇦🇺", name: "Australia", dialCode: "+61"),
            DialCountry(id: "DE", flag: "🇩🇪", name: "Germany", dialCode: "+49"),
            DialCountry(id: "FR", flag: "🇫🇷", name: "France", dialCode: "+33"),
            DialCountry(id: "JP", flag: "🇯🇵", name: "Japan", dialCode: "+81"),
            DialCountry(id: "BR", flag: "🇧🇷", name: "Brazil", dialCode: "+55"),
            DialCountry(id: "MX", flag: "🇲🇽", name: "Mexico", dialCode: "+52"),
            DialCountry(id: "ES", flag: "🇪🇸", name: "Spain", dialCode: "+34"),
            DialCountry(id: "IT", flag: "🇮🇹", name: "Italy", dialCode: "+39"),
            DialCountry(id: "PH", flag: "🇵🇭", name: "Philippines", dialCode: "+63"),
            DialCountry(id: "NG", flag: "🇳🇬", name: "Nigeria", dialCode: "+234"),
            DialCountry(id: "KR", flag: "🇰🇷", name: "South Korea", dialCode: "+82"),
            DialCountry(id: "CN", flag: "🇨🇳", name: "China", dialCode: "+86"),
        ]
    }

    static func applyNationalFormat(_ input: String, country: DialCountry) -> String {
        let maxDigits = country.usesNANP ? 10 : 12
        let digits = String(input.filter(\.isNumber).prefix(maxDigits))
        if country.usesNANP {
            return formatNANP(digits)
        }
        return formatGroupedDigits(digits)
    }

    private static func formatNANP(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        if digits.count <= 3 { return String(digits) }
        if digits.count <= 6 {
            let a = digits.prefix(3)
            let b = digits.dropFirst(3)
            return "(\(a)) \(b)"
        }
        let a = digits.prefix(3)
        let b = digits.dropFirst(3).prefix(3)
        let c = digits.dropFirst(6)
        return "(\(a)) \(b)-\(c)"
    }

    private static func formatGroupedDigits(_ digits: String) -> String {
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && i % 3 == 0 { out += " " }
            out.append(ch)
        }
        return out
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
