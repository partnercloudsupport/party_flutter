import 'dart:async';
import 'package:flutter/material.dart';

import 'package:zgadula/localizations.dart';
import 'package:zgadula/store/tutorial.dart';
import 'package:zgadula/components/reveal/page_dragger.dart';
import 'package:zgadula/components/reveal/page_reveal.dart';
import 'package:zgadula/components/reveal/pager_indicator.dart';
import 'package:zgadula/components/reveal/pages.dart';
import 'package:zgadula/screens/home.dart';

class TutorialScreen extends StatefulWidget {
  @override
  TutorialScreenState createState() => new TutorialScreenState();
}

class TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  StreamController<SlideUpdate> slideUpdateStream;
  AnimatedPageDragger animatedPageDragger;

  int activeIndex = 0;
  int nextPageIndex = 0;
  SlideDirection slideDirection = SlideDirection.none;
  double slidePercent = 0.0;

  TutorialScreenState() {
    slideUpdateStream = new StreamController<SlideUpdate>();

    slideUpdateStream.stream.listen((SlideUpdate event) {
      setState(() {
        if (event.updateType == UpdateType.dragging) {
          slideDirection = event.direction;
          slidePercent = event.slidePercent;

          if (slideDirection == SlideDirection.leftToRight) {
            nextPageIndex = activeIndex - 1;
          } else if (slideDirection == SlideDirection.rightToLeft) {
            nextPageIndex = activeIndex + 1;
          } else {
            nextPageIndex = activeIndex;
          }
        } else if (event.updateType == UpdateType.doneDragging) {
          if (slidePercent > 0.2) {
            animatedPageDragger = new AnimatedPageDragger(
              slideDirection: slideDirection,
              transitionGoal: TransitionGoal.open,
              slidePercent: slidePercent,
              slideUpdateStream: slideUpdateStream,
              vsync: this,
            );
          } else {
            animatedPageDragger = new AnimatedPageDragger(
              slideDirection: slideDirection,
              transitionGoal: TransitionGoal.close,
              slidePercent: slidePercent,
              slideUpdateStream: slideUpdateStream,
              vsync: this,
            );

            nextPageIndex = activeIndex;
          }

          animatedPageDragger.run();
        } else if (event.updateType == UpdateType.animating) {
          slideDirection = event.direction;
          slidePercent = event.slidePercent;
        } else if (event.updateType == UpdateType.doneAnimating) {
          activeIndex = nextPageIndex;

          slideDirection = SlideDirection.none;
          slidePercent = 0.0;

          animatedPageDragger.dispose();
        }
      });
    });
  }

  skipTutorial() {
    TutorialModel.of(context).watch();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  List<PageViewModel> getPages(BuildContext context) {
    final pages = [
      PageViewModel(
        Theme.of(context).primaryColor,
        'assets/images/tutorial_1.png',
        AppLocalizations.of(context).tutorialFirstSectionHeader,
        AppLocalizations.of(context).tutorialFirstSectionDescription,
        AppLocalizations.of(context).tutorialSkip,
      ),
      PageViewModel(
        Theme.of(context).primaryColorDark,
        'assets/images/tutorial_2.png',
        AppLocalizations.of(context).tutorialSecondSectionHeader,
        AppLocalizations.of(context).tutorialSecondSectionDescription,
        AppLocalizations.of(context).tutorialSkip,
      ),
      PageViewModel(
        Theme.of(context).primaryColor,
        'assets/images/tutorial_3.png',
        AppLocalizations.of(context).tutorialThirdSectionHeader,
        AppLocalizations.of(context).tutorialThirdSectionDescription,
        AppLocalizations.of(context).tutorialSkip,
      ),
    ];

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    List<PageViewModel> pages = getPages(context);

    return new Scaffold(
      body: new Stack(
        children: [
          new Page(
            viewModel: pages[activeIndex],
            percentVisible: 1.0,
            onSkip: skipTutorial,
          ),
          new PageReveal(
            revealPercent: slidePercent,
            child: new Page(
              viewModel: pages[nextPageIndex],
              percentVisible: slidePercent,
              onSkip: skipTutorial,
            ),
          ),
          new PagerIndicator(
            viewModel: new PagerIndicatorViewModel(
              pages,
              activeIndex,
              slideDirection,
              slidePercent,
            ),
          ),
          new PageDragger(
            canDragLeftToRight: activeIndex > 0,
            canDragRightToLeft: activeIndex < pages.length - 1,
            slideUpdateStream: this.slideUpdateStream,
          ),
        ],
      ),
    );
  }
}
