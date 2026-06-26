import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isChecked = false;


  TextEditingController emailController =
  TextEditingController();

  TextEditingController usernameController =
  TextEditingController();

  TextEditingController passwordController =
  TextEditingController();

  TextEditingController confirmPasswordController =
  TextEditingController();

  Future<void> signUpUser() async {

    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
        ),
      );

      return;
    }

    if (!isChecked) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please accept Terms & Conditions",
          ),
        ),
      );

      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set({
        "email": emailController.text.trim(),
        "username": usernameController.text.trim(),
        "uid": userCredential.user!.uid,
        "createdAt": DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Signup Successful"),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );

    } on FirebaseAuthException catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? "Signup Failed",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xffF7F4F4),

      body: SafeArea(

        child: SingleChildScrollView(

          child: Column(

            children: [

              const SizedBox(height: 20),

              RichText(
                text: const TextSpan(
                  children: [

                    TextSpan(
                      text: "C",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),

                    TextSpan(
                      text: "onexus",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffF26A21),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Container(

                width: double.infinity,

                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 35,
                ),

                decoration: const BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    const Center(
                      child: Text(
                        "Create Your Account",

                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Center(
                      child: Text(
                        "Join Conexus Family",

                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),


                    const SizedBox(height: 18),

                    buildLabel("Email Address"),

                    buildTextField(
                      controller: emailController,
                      hint: "example@gmail.com",
                      icon: Icons.email_outlined,
                    ),

                    const SizedBox(height: 18),

                    buildLabel("Username"),

                    buildTextField(
                      controller: usernameController,
                      hint: "First_conexus",
                      icon: Icons.alternate_email,
                    ),

                    const SizedBox(height: 18),

                    buildLabel("Password"),

                    buildPasswordField(
                      controller: passwordController,
                      hint: "••••••••",
                      hide: hidePassword,

                      onTap: () {

                        setState(() {
                          hidePassword = !hidePassword;
                        });

                      },
                    ),

                    const SizedBox(height: 18),

                    buildLabel("Confirm Password"),

                    buildPasswordField(
                      controller:
                      confirmPasswordController,

                      hint: "••••••••",

                      hide: hideConfirmPassword,

                      onTap: () {

                        setState(() {

                          hideConfirmPassword =
                          !hideConfirmPassword;

                        });

                      },
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [

                        Checkbox(
                          value: isChecked,
                          activeColor: Colors.deepOrange,
                          onChanged: (value) {
                            setState(() {
                              isChecked = value!;
                            });
                          },
                        ),

                        const Text(
                          "Agree to ",
                          style: TextStyle(color: Colors.grey),
                        ),

                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Text(
                                    "Terms and Conditions",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [

                                        Text(
                                          "Welcome to Conexus. By creating an account and using our application, you agree to the following terms:",
                                          style: TextStyle(color: Colors.grey),
                                        ),

                                        SizedBox(height: 12),

                                        Text("1. Users must provide accurate information during registration."),
                                        SizedBox(height: 8),
                                        Text("2. Users are responsible for maintaining the security of their accounts and passwords."),
                                        SizedBox(height: 8),
                                        Text("3. Users must not post content that is illegal, abusive, hateful, threatening, or harmful to others."),
                                        SizedBox(height: 8),
                                        Text("4. Users must respect other community members and avoid harassment, bullying, or discrimination."),
                                        SizedBox(height: 8),
                                        Text("5. Users may not impersonate another person, organization, or institution."),
                                        SizedBox(height: 8),
                                        Text("6. Conexus reserves the right to remove content that violates these rules."),
                                        SizedBox(height: 8),
                                        Text("7. Conexus may suspend or terminate accounts involved in inappropriate, fraudulent, or harmful activities."),
                                        SizedBox(height: 8),
                                        Text("8. Users retain ownership of their content but grant Conexus permission to display content within the platform."),
                                        SizedBox(height: 8),
                                        Text("9. Conexus is not responsible for user-generated content posted by members."),
                                        SizedBox(height: 8),
                                        Text("10. We may update these Terms and Conditions from time to time. Continued use of the application indicates acceptance of any updates."),
                                        SizedBox(height: 12),

                                        Text(
                                          "By using Conexus, you acknowledge that you have read and agreed to these Terms and Conditions.",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepOrange,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            isChecked = true; // auto check when user reads and clicks agree
                                          });
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          "I Agree",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          "Close",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: const Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(

                      width: double.infinity,
                      height: 58,

                      decoration: BoxDecoration(

                        borderRadius:
                        BorderRadius.circular(30),

                        gradient: const LinearGradient(
                          colors: [
                            Color(0xffC93A00),
                            Color(0xffFF5B2E),
                          ],
                        ),

                        boxShadow: [
                          BoxShadow(
                            color:
                            Colors.orangeAccent
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),

                      child: ElevatedButton(

                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          Colors.transparent,

                          shadowColor:
                          Colors.transparent,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(30),
                          ),
                        ),

                        onPressed: () async {

                          await signUpUser();

                        },

                        child: const Text(
                          "Sign Up →",

                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    Center(

                      child: Row(

                        mainAxisAlignment:
                        MainAxisAlignment.center,

                        children: [

                          const Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),

                          GestureDetector(

                            onTap: () {

                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (context) =>
                                      LoginScreen(),
                                ),
                              );

                            },

                            child: const Text(
                              "Login",

                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget buildLabel(String text) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 8),

      child: Text(
        text,

        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget buildTextField({

    required TextEditingController controller,
    required String hint,
    required IconData icon,

  }) {

    return TextField(

      controller: controller,

      decoration: InputDecoration(

        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400), // 👈 added

        prefixIcon: Icon(
          icon,
          color: Colors.grey,
        ),

        filled: true,
        fillColor: Colors.white,

        contentPadding:
        const EdgeInsets.symmetric(
          vertical: 18,
        ),

        enabledBorder: OutlineInputBorder(

          borderRadius:
          BorderRadius.circular(14),

          borderSide: BorderSide(
            color: Colors.orange.shade100,
          ),
        ),

        focusedBorder: OutlineInputBorder(

          borderRadius:
          BorderRadius.circular(14),

          borderSide: const BorderSide(
            color: Colors.deepOrange,
          ),
        ),
      ),
    );
  }

  Widget buildPasswordField({

    required TextEditingController controller,
    required String hint,
    required bool hide,
    required VoidCallback onTap,

  }) {

    return TextField(

      controller: controller,
      obscureText: hide,

      decoration: InputDecoration(

        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400), // 👈 added

        prefixIcon: const Icon(
          Icons.lock_outline,
          color: Colors.grey,
        ),

        suffixIcon: IconButton(

          icon: Icon(
            hide
                ? Icons.visibility_off
                : Icons.visibility,

            color: Colors.grey,
          ),

          onPressed: onTap,
        ),

        filled: true,
        fillColor: Colors.white,

        contentPadding:
        const EdgeInsets.symmetric(
          vertical: 18,
        ),

        enabledBorder: OutlineInputBorder(

          borderRadius:
          BorderRadius.circular(14),

          borderSide: BorderSide(
            color: Colors.orange.shade100,
          ),
        ),

        focusedBorder: OutlineInputBorder(

          borderRadius:
          BorderRadius.circular(14),

          borderSide: const BorderSide(
            color: Colors.deepOrange,
          ),
        ),
      ),
    );
  }
}