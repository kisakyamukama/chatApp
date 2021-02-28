import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_chat_app/ui/chat/chat_home.dart';
import 'package:my_chat_app/ui/chat/widgets/loading.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final String title;
  LoginScreen({Key key, this.title}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  User currentUser;

  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ChatHomeScreen(
                    currentUserId: prefs.getString('id'),
                  )));
    }

    this.setState(() {
      isLoading = false;
    });
  }

  // signin
  Future<Null> handleSignIn() async {
    try {
      prefs = await SharedPreferences.getInstance();

      this.setState(() {
        isLoading = true;
      });

      GoogleSignInAccount googleUser = await googleSignIn.signIn();
      GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      User firebaseUser =
          (await firebaseAuth.signInWithCredential(credential)).user;

      if (firebaseUser != null) {
        // Check if user is already signed up
        final QuerySnapshot result = await FirebaseFirestore.instance
            .collection('users')
            .where('id', isEqualTo: firebaseUser.uid)
            .get();
        final List<DocumentSnapshot> documents = result.docs;
        if (documents.length == 0) {
          // Update data to server for new user
          FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .set({
            'userName': firebaseUser.displayName,
            'photoUrl': firebaseUser.photoURL,
            'id': firebaseUser.uid,
            'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
            'chattingWith': null
          });

          // Write data to local
          currentUser = firebaseUser;
          await prefs.setString('id', currentUser.uid);
          await prefs.setString('userName', currentUser.displayName);
          await prefs.setString('photoUrl', currentUser.photoURL);
        } else {
          // Write data to local
          await prefs.setString('id', documents[0].data()['id']);
          await prefs.setString('userName', documents[0].data()['userName']);
          await prefs.setString('photoUrl', documents[0].data()['photoUrl']);
          await prefs.setString('aboutMe', documents[0].data()['aboutMe']);
        }

        Fluttertoast.showToast(msg: "Sign in success");
        this.setState(() {
          isLoading = false;
        });
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatHomeScreen(
                      currentUserId: firebaseUser.uid,
                    )));
      } else {
        Fluttertoast.showToast(msg: "Sign in failed");
        this.setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          title: Text(
            widget.title,
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          )),
      body: Stack(
        children: <Widget>[
          Center(
            child: FlatButton(
              onPressed: () => handleSignIn().catchError((err) {
                Fluttertoast.showToast(msg: "Sign in failed");
                this.setState(() {
                  isLoading = false;
                });
              }),
              child: Text(
                'SIGN IN WITH GOOGLE',
                style: TextStyle(fontSize: 16.0),
              ),
              color: Color(0xffdd4b39),
              highlightColor: Color(0xffff7f7f),
              splashColor: Colors.transparent,
              textColor: Colors.white,
              padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0),
            ),
          ),
          Positioned(child: isLoading ? Loading() : Container())
        ],
      ),
    );
  }
}
