import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zgadula/components/fab.dart';
import 'package:zgadula/localizations.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:sensors/sensors.dart';
import 'package:zgadula/services/audio.dart';
import 'package:zgadula/services/formatters.dart';
import 'package:zgadula/services/vibration.dart';
import 'package:zgadula/services/analytics.dart';

import 'package:zgadula/store/category.dart';
import 'package:zgadula/models/category.dart';
import 'package:zgadula/store/question.dart';
import 'package:zgadula/store/settings.dart';
import 'package:zgadula/screens/game_score.dart';

class CategoryPlayScreen extends StatefulWidget {
  CategoryPlayScreen({Key key}) : super(key: key);

  @override
  CategoryPlayScreenState createState() => CategoryPlayScreenState();
}

class CategoryPlayScreenState extends State<CategoryPlayScreen> {
  static const rotationBorder = 18.0;

  Timer gameTimer;
  int secondsMax;
  int secondsLeft = 3;
  bool isStarted = false;
  bool isPaused = false;
  StreamSubscription<dynamic> _rotateSubscription;

  @override
  void initState() {
    super.initState();
    startTimer();

    Category category = CategoryModel.of(context).currentCategory;

    QuestionModel.of(context).generateCurrentQuestions(category.id);

    secondsMax = SettingsModel.of(context).roundTime;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
    ]);

    if (SettingsModel.of(context).isRotationControlEnabled) {
      enableRotationControl();
    }

    AnalyticsService.logEvent('play_game', {'category': category.name});
  }

  @protected
  @mustCallSuper
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    if (_rotateSubscription != null) {
      _rotateSubscription.cancel();
    }

    super.dispose();
    stopTimer();
  }

  enableRotationControl() {
    bool safePosition = true;
    _rotateSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      if (!isStarted || isPaused) {
        return;
      }

      if (event.z > rotationBorder) {
        if (safePosition) {
          safePosition = false;
          handleInvalid();
        }
      } else if (event.z < -rotationBorder) {
        if (safePosition) {
          safePosition = false;
          handleValid();
        }
      } else if (event.z.abs() > rotationBorder / 2) {
        safePosition = true;
      }
    });
  }

  stopTimer() {
    if (gameTimer != null && gameTimer.isActive) {
      gameTimer.cancel();
    }
  }

  startTimer() {
    gameTimer = Timer.periodic(const Duration(seconds: 1), gameLoop);
  }

  gameLoop(Timer timer) {
    if (secondsLeft == 0) {
      handleTimeout();
      return;
    }

    setState(() {
      secondsLeft -= 1;
    });
  }

  showScore() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScoreScreen(),
      ),
    );
  }

  Future<bool> confirmBack() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(AppLocalizations.of(context).gameCancelConfirmation),
          actions: <Widget>[
            FlatButton(
              child: Text(AppLocalizations.of(context).gameCancelApprove),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            FlatButton(
              child: Text(AppLocalizations.of(context).gameCancelDeny),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      },
    );
  }

  nextQuestion() {
    stopTimer();

    QuestionModel.of(context).setNextQuestion();
    if (QuestionModel.of(context).currentQuestion == null) {
      showScore();

      return;
    }

    setState(() {
      isPaused = false;
      secondsLeft = secondsMax;
    });

    startTimer();
  }

  handleValid() {
    AudioService.valid(context);
    VibrationService.vibrate(context);
    QuestionModel.of(context).markQuestionAsValid();

    setState(() {
      isPaused = true;
      secondsLeft = 1;
    });
  }

  handleInvalid() {
    AudioService.invalid(context);
    VibrationService.vibrate(context);
    QuestionModel.of(context).markQuestionAsInvalid();

    setState(() {
      isPaused = true;
      secondsLeft = 1;
    });
  }

  handleTimeout() {
    if (isPaused) {
      nextQuestion();
    } else if (isStarted) {
      handleInvalid();
    } else {
      setState(() {
        isStarted = true;
        secondsLeft = secondsMax;
      });
    }
  }

  Widget buildHeader(text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 64.0,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget buildHeaderIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Icon(
        icon,
        size: 96.0,
        color: Theme.of(context).textTheme.body1.color,
      ),
    );
  }

  Widget buildSplashContent(Widget child, Color background, [IconData icon]) {
    return Container(
      decoration: BoxDecoration(color: background),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Center(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGameContent() {
    String timeLeft = FormatterService.secondsToTime(secondsLeft);

    return ScopedModelDescendant<QuestionModel>(
      builder: (context, child, model) {
        return GestureDetector(
          onTap: handleValid,
          onDoubleTap: handleInvalid,
          behavior: HitTestBehavior.opaque,
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: buildHeader(model.currentQuestion.name),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    timeLeft,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildContent() {
    if (isPaused) {
      IconData iconData = Icons.sentiment_very_dissatisfied;
      Color background = Theme.of(context).errorColor;

      if (QuestionModel.of(context).currentQuestion.isPassed) {
        iconData = Icons.sentiment_very_satisfied;
        background = Theme.of(context).accentColor;
      }

      return buildSplashContent(buildHeaderIcon(iconData), background);
    } else if (isStarted) {
      return buildGameContent();
    }

    return buildSplashContent(
      buildHeader(FormatterService.secondsToTime(secondsLeft)),
      Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await confirmBack();
      },
      child: Scaffold(
        floatingActionButtonLocation:
            CustomFloatingActionButtonLocation.startFloat,
        floatingActionButton: isPaused
            ? null
            : FloatingActionButton(
                elevation: 0.0,
                child: Icon(Icons.arrow_back),
                backgroundColor: Theme.of(context).primaryColor,
                onPressed: () async {
                  if (await confirmBack()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
        body: buildContent(),
      ),
    );
  }
}
