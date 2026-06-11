import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {

  final TextEditingController searchController = TextEditingController();

  List<String> users = [
    "Rupesh Yadav",
    "Ujjwal Aacharya",
    "Sandesh Sahi",
    "Sandish Prajapati ",
    "Meta",
    "Instagram",
    "Softwarica College",
  ];

  List<String> filteredUsers = [];

  @override
  void initState() {
    super.initState();
    filteredUsers = users;
  }

  void searchUser(String value) {
    setState(() {
      filteredUsers = users
          .where(
            (user) =>
            user.toLowerCase().contains(value.toLowerCase()),
      )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [

            /// Search Field
            TextField(
              controller: searchController,
              onChanged: searchUser,

              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Search Results
            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,

                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),

                      title: Text(filteredUsers[index]),

                      trailing: const Icon(Icons.arrow_forward_ios),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}