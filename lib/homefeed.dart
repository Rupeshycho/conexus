import 'package:flutter/material.dart';

void main(){
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeFeed(),
  ));
}
class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {

  int selectedIndex = 0;

  final List<String> screenNames = [
    "Home Feed",
    "Search Users",
    "Create Reel",
    "Chats",
    "Profile",
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      // ================= APP BAR =================
      appBar: AppBar(

        backgroundColor: Colors.white,
        elevation: 1,

        // LEFT PROFILE ICON
        leading: Padding(
          padding: const EdgeInsets.all(8.0),

          child: CircleAvatar(
            backgroundColor: Colors.orange.shade100,

            child: const Icon(
              Icons.person,
              color: Colors.black,
            ),
          ),
        ),

        // CENTER LOGO/TEXT
        title: const Text(
          "Conexus",
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),

        centerTitle: true,

        // RIGHT NOTIFICATION ICON
        actions: [

          IconButton(
            onPressed: () {},

            icon: const Icon(
              Icons.notifications_none,
              color: Colors.orange,
              size: 30,
            ),
          ),
        ],
      ),

      // ================= BODY =================
      body: Container(

        width: double.infinity,
        color: const Color(0xfff8f3f3),

        child: Center(

          child: Container(

            height: 200,
            width: 300,

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(12),

              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                ),
              ],
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                Text(
                  screenNames[selectedIndex],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  "Content will appear here",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ================= FLOATING + BUTTON =================
      floatingActionButton: FloatingActionButton(

        backgroundColor: Colors.deepOrange,

        onPressed: () {

          setState(() {
            selectedIndex = 5;
          });

        },

        child: const Icon(
          Icons.add,
          size: 35,
          color: Colors.white,
        ),
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.endFloat,

      // ================= BOTTOM NAVIGATION =================
      bottomNavigationBar: BottomAppBar(

        shape: const CircularNotchedRectangle(),

        notchMargin: 1,

        child: SizedBox(

          height: 65,

          child: Row(

            mainAxisAlignment: MainAxisAlignment.spaceAround,

            children: [

              // HOME
              navItem(
                icon: Icons.home,
                label: "HOME",
                index: 0,
              ),

              // SEARCH
              navItem(
                icon: Icons.search,
                label: "SEARCH",
                index: 1,
              ),
              navItem(
                  icon: Icons.video_collection,
                  label: "REELS",
                  index: 2,
              ),


              // EMPTY SPACE FOR FAB
              // const SizedBox(width: 40),

              // CHATS
              navItem(
                icon: Icons.chat_bubble_outline,
                label: "CHATS",
                index: 3,
              ),

              // PROFILE
              navItem(
                icon: Icons.person_outline,
                label: "PROFILE",
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= NAV ITEM WIDGET =================
  Widget navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {

    bool isSelected = selectedIndex == index;

    return GestureDetector(

      onTap: () {

        setState(() {
          selectedIndex = index;
        });

      },

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Icon(
            icon,
            color: isSelected ? Colors.orange : Colors.grey,
          ),

          Text(
            label,

            style: TextStyle(
              color: isSelected ? Colors.orange : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}