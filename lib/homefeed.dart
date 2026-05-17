import 'package:flutter/material.dart';


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
    "Add Posts/Reels",
    "View Reels",
    "Chats",

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

      body: IndexedStack(
        index: selectedIndex,
        children: [
          Center(child: Text(screenNames[0])),
          Center(child: Text(screenNames[1])),
          Center(child: Text(screenNames[2])),
          Center(child: Text(screenNames[3])),
          Center(child: Text(screenNames[4])),
        ],
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