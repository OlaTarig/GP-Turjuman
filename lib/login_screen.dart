import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
         
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
             
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF9E3), Color(0xFFFFB382)],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 90),
                
                Image.asset(
                  'assets/logoT.png', 
                  height: 130,
                  errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.auto_awesome, size: 80, color: Colors.orange),
                ),
                const SizedBox(height: 30),
                
                   
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const Text(
                            "Login",
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Welcome back! Login to your account",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 40),
                          
                            
                          _inputField("Email", "example@mail.com"),
                          const SizedBox(height: 20),
                          
                              
                          _buildPasswordField(),
                          
                              
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text("Forgot Password?", 
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          //   (Login)
                          InkWell(
                            onTap: () {
                              // المنطق  
                            },
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [Color(0xFFFDBB84), Color(0xFFFFD98F)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 25),
                          
                               
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? "),
                              GestureDetector(
                                onTap: () {
                                       
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          //      
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF4A4A4A), size: 20),
                onPressed: () {
                  Navigator.pop(context);    
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

        
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 5, bottom: 8),
          child: Text("Password", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        TextField(
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: "Enter your password",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15), 
              borderSide: BorderSide.none
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }

  //    
  Widget _inputField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 8),
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15), 
              borderSide: BorderSide.none
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }
}