import 'package:flutter/material.dart';

void main(){
  runApp(const HomeFeed());
}

class HomeFeed extends StatefulWidget {
  const HomeFeed({super.key});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {

  int selectedIndex = 0;

  final List<String> screenNames = [
    "Home Feed ",
    "Search Users",
    "View Reels",
    "Chats",
    "Add Posts/Reels"
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      // app bar
      appBar: AppBar(

        backgroundColor: Colors.white,
        elevation: 1,



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



        title: const Text(
          "Conexus",
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),

        centerTitle: true,



        actions: [

          IconButton(
            onPressed: ( ) {

            },

            icon: const Icon(
              Icons.notifications_none,
              color: Colors.orange,
              size: 30,
            ),
          ),
        ],
      ),


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

      //Floating Action button center


      // Bottom Navigation
      bottomNavigationBar: BottomAppBar(

        shape: const CircularNotchedRectangle(),

        notchMargin: 2,

        child: SizedBox(

          height: 65,

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              navItem(icon: Icons.home, label: "HOME", index: 0),

              navItem(icon: Icons.search, label: "SEARCH", index: 1),

              navItem(icon: Icons.add_box_outlined, label: "CREATE", index: 2),

              navItem(icon: Icons.video_collection, label: "REELS", index: 3),

              navItem(icon: Icons.chat_bubble_outline, label: "CHATS", index: 4),
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