import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AuthSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isPresented: Bool
    @State private var isSignInPasswordVisible = false
    @State private var isCreatePasswordVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 22) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 66, weight: .regular))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 150, alignment: .center)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("クラウド同期（オプション）")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Firebase を使用してデータを安全に同期します。\n同期はいつでも設定からオン／オフできます。")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("サインイン")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.success)
                        Text("既存のアカウントでサインインしてデータを同期します。")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AuthInputField(
                        title: "メールアドレス",
                        placeholder: "メールアドレスを入力",
                        text: $viewModel.syncEmail,
                        keyboardType: .emailAddress
                    )
                    AuthPasswordField(
                        title: "パスワード",
                        placeholder: "パスワードを入力",
                        text: $viewModel.syncPassword,
                        isVisible: $isSignInPasswordVisible
                    )
                    Button {
                        viewModel.sendPasswordReset()
                    } label: {
                        Text("パスワードをお忘れですか？")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.success)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.syncEmail.isEmpty)

                    Button {
                        viewModel.signInToSync()
                    } label: {
                        Text("サインイン")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(AppColors.success, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
                }
                .authCard()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("アカウント作成")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.success)
                        Text("新しいアカウントを作成してクラウド同期を利用します。")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AuthInputField(
                        title: "メールアドレス",
                        placeholder: "メールアドレスを入力",
                        text: $viewModel.syncEmail,
                        keyboardType: .emailAddress
                    )
                    AuthPasswordField(
                        title: "パスワード",
                        placeholder: "パスワードを入力",
                        text: $viewModel.syncPassword,
                        isVisible: $isCreatePasswordVisible
                    )
                    Text("※ 8文字以上のパスワードを設定してください。")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)

                    Button {
                        viewModel.createSyncAccount()
                    } label: {
                        Text("アカウント作成")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppColors.success, lineWidth: 1.5)
                            }
                    }
                    .disabled(viewModel.syncEmail.isEmpty || viewModel.syncPassword.isEmpty)
                }
                .authCard()

                if let error = viewModel.app.syncStatus.errorMessage {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Color.red)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("同期エラー")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.red)
                            Text(error)
                                .font(.system(size: 16))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("通信は暗号化され、安全に保護されています。")
                        .font(.system(size: 14))
                }
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("クラウド同期")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.app.syncStatus.isAuthenticated) { isAuthenticated in
            guard isAuthenticated else { return }
            isPresented = false
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { isPresented = false }
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") { isPresented = false }
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.success)
            }
        }
    }
}

private struct AuthInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            TextField(placeholder, text: $text)
                .font(.system(size: 18))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                }
        }
    }
}

private struct AuthPasswordField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 18))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .frame(height: 54)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            }
        }
    }
}

private extension View {
    func authCard() -> some View {
        self
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }
}
