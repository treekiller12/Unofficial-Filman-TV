import 'package:flutter/material.dart';
import 'package:unofficial_filman_client/notifiers/filman.dart';
import 'package:unofficial_filman_client/types/home_page.dart';
import 'package:unofficial_filman_client/widgets/error_handling.dart';
import 'package:unofficial_filman_client/utils/updater.dart';
import 'package:unofficial_filman_client/screens/film.dart';
import 'package:unofficial_filman_client/types/film.dart';
import 'package:unofficial_filman_client/widgets/search.dart';
import 'package:provider/provider.dart';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:flutter/services.dart';  // <-- Add this import to access RawKeyEvent and LogicalKeyboardKey

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late Future<HomePageResponse> homePageLoader;
  int _focusedIndex = -1;
  String _focusedCategory = '';
  final FocusNode _focusNode = FocusNode(); // FocusNode for managing focus

  @override
  void initState() {
    super.initState();
    homePageLoader =
        Provider.of<FilmanNotifier>(context, listen: false).getFilmanPage();
    checkForUpdates(context);
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (final context) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: const SearchModal(),
        );
      },
    );
  }

  // Funkcja budująca kartę filmu
  Widget _buildFilmCard(BuildContext context, Film film, String category, int index) {
    bool isSelected = _focusedIndex == index && _focusedCategory == category;

    return Focus(
      onFocusChange: (focused) {
        setState(() {
          if (focused) {
            _focusedIndex = index;
            _focusedCategory = category;
          } else if (_focusedIndex == index && _focusedCategory == category) {
            _focusedIndex = -1;
            _focusedCategory = '';
          }
        });
      },
      onKey: (FocusNode node, RawKeyEvent event) {
        // Handling key events: When select button is pressed (logicalKey)
        if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
          // Przechodzimy do szczegółów filmu
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FilmScreen(
                url: film.link,
                title: film.title,
                image: film.imageUrl,
              ),
            ),
          );
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          // Na kliknięcie przechodzimy do ekranu filmu
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FilmScreen(
                url: film.link,
                title: film.title,
                image: film.imageUrl,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isSelected
              ? (Matrix4.identity()..scale(1.1, 1.1)) // Powiększamy film, gdy jest wybrany
              : Matrix4.identity(),
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: Colors.white, width: 4.0) : null, // Biała obramówka przy focusie
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12.0)),
            child: FastCachedImage(
              url: film.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, progress) => SizedBox(
                height: 180,
                width: 116,
                child: Center(
                  child: CircularProgressIndicator(
                      value: progress.progressPercentage.value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    return FutureBuilder<HomePageResponse>(
      future: homePageLoader,
      builder: (final BuildContext context,
          final AsyncSnapshot<HomePageResponse> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return ErrorHandling(
              error: snapshot.error!,
              onLogin: (final auth) => setState(() {
                    homePageLoader =
                        Provider.of<FilmanNotifier>(context, listen: false)
                            .getFilmanPage();
                  }));
        }

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
              child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                homePageLoader =
                    Provider.of<FilmanNotifier>(context, listen: false)
                        .getFilmanPage();
              });
            },
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final String category
                        in snapshot.data?.categories ?? [])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20),
                            ),
                            SizedBox(
                              height: 180.0,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    snapshot.data?.getFilms(category)?.length ?? 0,
                                itemBuilder: (context, index) {
                                  final films = snapshot.data?.getFilms(category);
                                  if (films != null && index < films.length) {
                                    final film = films[index];
                                    return _buildFilmCard(context, film, category, index);
                                  } else {
                                    return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )),
          floatingActionButton: Focus(
            focusNode: _focusNode,
            onFocusChange: (hasFocus) {
              setState(() {
                // Możesz ustawić inny stan w zależności od tego, czy przycisk ma fokus
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: _focusNode.hasFocus
                  ? Matrix4.identity().scaled(1.2, 1.2)  // Zmieniono na .scaled()
                  : Matrix4.identity(), // Zwykły rozmiar, gdy nie ma fokus
              child: FloatingActionButton.extended(
                onPressed: _showBottomSheet,
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8.0),
                    Text("Szukaj"),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
