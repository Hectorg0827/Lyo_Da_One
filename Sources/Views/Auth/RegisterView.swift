import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var rootViewModel: RootViewModel
    @ObservedObject var authService: AuthService
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.newPassword)
                }
                .padding(.horizontal)
                
                if let error = authService.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                    Task {
                        await authService.register(name: name, email: email, password: password)
                        if authService.isAuthenticated {
                            rootViewModel.isAuthenticated = true
                            isPresented = false
                        }
                    }
                }) {
                    if authService.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .disabled(name.isEmpty || email.isEmpty || password.isEmpty || authService.isLoading)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}
