import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String clientId = '470087dfa9d94473ad7bbc2b521aa8e0';
const String clientSecret = '778860741eb4437da245bd43feef8eac';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme:ThemeData(
        fontFamily:'Poppins'),
      home: const ArtistSearchScreen(),
    );
  }
}

class ArtistSearchScreen extends StatefulWidget {
  const ArtistSearchScreen({super.key});

  @override
  _ArtistSearchScreenState createState() => _ArtistSearchScreenState();
}

class _ArtistSearchScreenState extends State<ArtistSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _finder = TextEditingController();
  String? _artistInfo;
  String? _artistName;
  List<String> _allTracks = [];
  List<String> _filteredTracks = [];
  String? _artistImage;
  bool _isLoading = false;

  Future<String?> _getSpotifyAccessToken() async {
    final String credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['access_token'];
    } else {
      print('Failed to get access token: ${response.statusCode}');
      return null;
    }
  }

  Future<void> _getArtistAndallTracks(String artistName) async {
    setState(() {
      _isLoading = true;
      _allTracks = [];
      _finder.clear();
    });

    final accessToken = await _getSpotifyAccessToken();
    if (accessToken == null) return;

    final artistResponse = await http.get(
      Uri.parse('https://api.spotify.com/v1/search?q=$artistName&type=artist&limit=1'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (artistResponse.statusCode == 200) {
      final Map<String, dynamic> artistData = json.decode(artistResponse.body);
      if (artistData['artists']['items'].isNotEmpty) {
        final artist = artistData['artists']['items'][0];
        final artistId = artist['id'];
        _artistImage = artist['images'].isNotEmpty ? artist['images'][0]['url'] : null;
        _artistName=artist['name'];
        setState(() {
          _artistInfo = 'Artist: ${artist['name']}\n'
              'Followers: ${artist['followers']['total']}\n'
              'Genres: ${artist['genres'].join(', ')}\n'
              'Popularity: ${artist['popularity']}';
        });

        await _getAllTracks(artistId, accessToken);
      } else {
        setState(() {
          _artistInfo = 'No artist found.';
        });
      }
    } else {
      print('Error fetching artist info: ${artistResponse.statusCode}');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getAllTracks(String artistId, String token) async {
    List<String> allTracks = [];
    try {
      // Fetch all albums for the artist
      final albumsResponse = await http.get(
        Uri.parse('https://api.spotify.com/v1/artists/$artistId/albums?limit=50&include_groups=album,single'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (albumsResponse.statusCode == 200) {
        final Map<String, dynamic> albumsData = json.decode(albumsResponse.body);
        final List<dynamic> albums = albumsData['items'];

        // Fetch tracks for each album
        for (var album in albums) {
          final albumId = album['id'];
          final tracksResponse = await http.get(
            Uri.parse('https://api.spotify.com/v1/albums/$albumId/tracks'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );

          if (tracksResponse.statusCode == 200) {
            final Map<String, dynamic> tracksData = json.decode(tracksResponse.body);
            final List<dynamic> tracks = tracksData['items'];
            allTracks.addAll(tracks.map((track) => track['name'].toString()).toList());
          } else {
            print('Error fetching tracks for album $albumId: ${tracksResponse.statusCode}');
          }
        }
        setState(() {
          _allTracks = allTracks.toSet().toList(); // Remove duplicates
          _filteredTracks=_allTracks;

        });
      } else {
        print('Error fetching albums: ${albumsResponse.statusCode}');
      }
    } catch (e) {
      print('Error fetching all tracks: $e');
    }
  }

  Future<void> _getLyrics(String song,String? artist) async {
    try {
      final response = await http.get(
        Uri.parse('https://lrclib.net/api/get?artist_name=$artist&track_name=$song'),
      );

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedResponse) as Map<String, dynamic>;
        final rawLyrics = data['plainLyrics'] as String?;
        if (rawLyrics != null) {
          final filteredLyrics = _filterInappropriateWords(rawLyrics);

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Lyrics: $song'),
              backgroundColor: Colors.cyanAccent,
              content: SingleChildScrollView(
                child: Text(filteredLyrics,style: const TextStyle(fontWeight: FontWeight.bold),),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',style: TextStyle(color:Colors.red),),
                ),
              ],
            ),
          );
        } else {
          throw Exception('Lyrics not found.');
        }
      } else {
        throw Exception('Failed to fetch lyrics. HTTP ${response.statusCode}');
      }
    } catch (e) {
      // print('Error fetching lyrics: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lyrics not found!'),
          backgroundColor: Colors.red,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',style: TextStyle(color:Colors.red),),
            ),
          ],
        ),
      );

    }
  }
  String _filterInappropriateWords(String lyrics) {
    final List<String> inappropriateWords = [
      'bitch',
      'nigga',
      'shit',
      'niggas',
      'motherfuckers',
      'motherfucker',
      'ass',
      'fuck',
      'fucking',
      'fuckin',
      'fuckin',
      'fucks',
      'pussy',
      'dick'// Add more words as needed
    ];

    String filteredLyrics = lyrics;

    for (final word in inappropriateWords) {
      final regex = RegExp(r'\b' + word + r'\b', caseSensitive: false);
      filteredLyrics = filteredLyrics.replaceAllMapped(regex, (match) {
        return '*' * match.group(0)!.length;
      });
    }

    return filteredLyrics;
  }

  @override
  void initState() {
    super.initState();

    // Initialize the filtered tracks list
    _filteredTracks = _allTracks;

    // Add a listener to the _finder TextEditingController
    _finder.addListener(() {
      setState(() {
        // Update the filtered tracks list based on the input
        _filteredTracks = _allTracks
            .where((track) =>
            track.toLowerCase().contains(_finder.text.toLowerCase()))
            .toList();
      });
    });
  }
  @override
  void dispose() {
    _finder.dispose();
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Artist Search',),
        backgroundColor: Colors.cyanAccent,
        titleTextStyle: const TextStyle(fontSize: 30,color:Colors.black,fontWeight:FontWeight.bold,fontFamily: 'Poppins'),
        centerTitle: true,
      ),
      backgroundColor: Colors.blueGrey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              cursorColor: Colors.cyanAccent,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Enter artist name',
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                labelStyle: TextStyle(color: Colors.white70)
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _getArtistAndallTracks(_controller.text);
                  _filteredTracks=_allTracks;
                }
              },
              child: const Text('Search',style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold),),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(color: Colors.cyanAccent,),
            if (_artistInfo != null)
              Text(
                _artistInfo!,
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
              ),
            const SizedBox(height: 20),
            if (_artistImage != null)
              Image.network(
                _artistImage!,
                width: 150,  // Set desired width
                height: 150, // Set desired height
                fit: BoxFit.cover, // Optional, to adjust how the image fits within the bounds
              ),

            if (_allTracks.isNotEmpty) ...[
              const Text('\nAll Tracks:\n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,color:Colors.white)),
              TextField(
                controller: _finder,
                cursorColor: Colors.cyanAccent,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'find a song:',
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                    labelStyle: TextStyle(color: Colors.white70)
                ),
              ),
              ListView.builder(
                shrinkWrap: true, // Ensures the ListView fits within its parent (Column in this case)
                physics: const NeverScrollableScrollPhysics(), // Prevents independent scrolling
                itemCount: _filteredTracks.length,
                itemBuilder: (context, index) {
                  final track = _filteredTracks[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    elevation: 4, // Adds shadow effect
                    child: ListTile(
                      title: Text(
                        track,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onTap: () {
                        _getLyrics(track, _artistName);
                      },
                    ),
                  );
                },
              ),
            ],

          ],
        ),
      ),
    );
  }
}
