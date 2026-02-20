import SwiftUI
import PhotosUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showProfileEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Text("SETTINGS")
                    .font(.vonique(46, fallbackWeight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)

                profileSummary
                hapticsSection
                volumeSection(title: "MUSIC", value: viewModel.settings.musicVolume) { viewModel.updateMusic($0) }
                volumeSection(title: "FX", value: viewModel.settings.fxVolume) { viewModel.updateFX($0) }

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    actionButtonTitle("PRIVACY POLICY")
                }

                NavigationLink {
                    DataUsageConsentView()
                } label: {
                    actionButtonTitle("DATA USAGE CONSENT")
                }

                NavigationLink {
                    HelpView()
                } label: {
                    actionButtonTitle("HELP")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showProfileEditor = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                }
            }
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorSheet(viewModel: viewModel)
        }
    }

    private var profileSummary: some View {
        HStack(spacing: 14) {
            profileImage

            VStack(alignment: .leading, spacing: 6) {
                Text("USER")
                    .font(.vonique(20, fallbackWeight: .regular))
                    .foregroundStyle(.black)

                Text(viewModel.settings.profileName)
                    .font(.vonique(28, fallbackWeight: .regular))
                    .foregroundStyle(.black)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var profileImage: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.55), lineWidth: 2)
                .frame(width: 74, height: 74)
                .background(Circle().fill(Color.white.opacity(0.65)))

            if let data = viewModel.settings.profileImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipShape(Circle())
            } else {
                DefaultProfileAvatar()
                    .frame(width: 54, height: 54)
            }
        }
    }

    private var hapticsSection: some View {
        HStack {
            Text("HAPTICS")
                .font(.vonique(34, fallbackWeight: .regular))
                .foregroundStyle(.black)

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.settings.hapticsEnabled },
                set: { viewModel.updateHaptics($0) }
            ))
            .labelsHidden()
            .tint(.black)
        }
    }

    private func volumeSection(title: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.vonique(34, fallbackWeight: .regular))
                .foregroundStyle(.black)

            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: 0...1)
            .tint(.black)
            .padding(.horizontal, 16)
        }
    }

    private func actionButtonTitle(_ title: String) -> some View {
        Text(title)
            .font(.vonique(24, fallbackWeight: .regular))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.32), lineWidth: 1))
    }
}

private struct ProfileEditorSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var nameDraft = ""
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.55), lineWidth: 2)
                            .frame(width: 130, height: 130)
                            .background(Circle().fill(Color.white.opacity(0.72)))

                        if let data = viewModel.settings.profileImageData,
                           let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            DefaultProfileAvatar()
                                .frame(width: 88, height: 88)
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text("UPLOAD")
                            .font(.vonique(24, fallbackWeight: .regular))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.24), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("USER NAME")
                            .font(.vonique(34, fallbackWeight: .medium))
                            .foregroundStyle(.black)

                        TextField("Enter username", text: $nameDraft)
                            .font(.vonique(24, fallbackWeight: .regular))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black.opacity(0.22), lineWidth: 1)
                            )

                        Text(viewModel.nameCooldownMessage)
                            .font(.vonique(18, fallbackWeight: .regular))
                            .foregroundStyle(.black)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            viewModel.updateProfileName(nameDraft)
                        } label: {
                            Text("SAVE NAME")
                                .font(.vonique(24, fallbackWeight: .regular))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.92))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.black.opacity(0.24), lineWidth: 1))
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let warning = viewModel.nameWarning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let warning = viewModel.imageWarning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PROFILE")
                        .font(.vonique(30, fallbackWeight: .medium))
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.black)
                }
            }
            .onAppear {
                nameDraft = viewModel.settings.profileName
            }
            .onChange(of: selectedPhoto) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            viewModel.setProfileImage(data: data)
                        }
                    }
                }
            }
        }
    }
}

private struct DefaultProfileAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.05))
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.68, green: 0.46, blue: 0.92),
                            Color(red: 0.86, green: 0.74, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(2)
        }
    }
}
