library duration_time_picker;

import 'dart:math' as math;

import 'package:flutter/material.dart';

const Duration _kDialAnimateDuration = Duration(milliseconds: 200);

const double _kDurationPickerWidthPortrait = 328.0;

const double _kDurationPickerHeightPortrait = 380.0;

const double _kTwoPi = 2 * math.pi;
const double _kPiByTwo = math.pi / 2;

const double _kCircleTop = _kPiByTwo;

/// Use [DialPainter] to style the durationPicker to your style.
class DialPainter extends CustomPainter {
  const DialPainter({
    required this.context,
    required this.circleColor,
    required this.accentColor,
    required this.theta,
    required this.textDirection,
    required this.selectedValue,
    required this.pct,
    required this.baseUnitMultiplier,
    required this.baseUnitHand,
    required this.baseUnit,
    required this.labelStyle,
    required this.backgroundColor,
  });

  final Color? circleColor;
  final Color accentColor;
  final double theta;
  final TextDirection textDirection;
  final int? selectedValue;
  final BuildContext context;
  final TextStyle? labelStyle;
  final double pct;
  final int baseUnitMultiplier;
  final int baseUnitHand;
  final BaseUnit baseUnit;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    const epsilon = .001;
    const sweep = _kTwoPi - epsilon;
    const startAngle = -math.pi / 2.0;

    final radius = size.shortestSide / 2.0;
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final centerPoint = center;

    final pctTheta = (0.25 - (theta % _kTwoPi) / _kTwoPi) % 1.0;

    // Draw the background outer ring
    canvas.drawCircle(centerPoint, radius, Paint()..color = circleColor!);

    // Draw a translucent circle for every secondary unit
    for (var i = 0; i < baseUnitMultiplier; i = i + 1) {
      canvas.drawCircle(
        centerPoint,
        radius,
        Paint()..color = accentColor.withOpacity((i == 0) ? 0.3 : 0.1),
      );
    }

    // Draw the inner background circle
    canvas.drawCircle(
      centerPoint,
      radius * 0.88,
      Paint()..color = backgroundColor,
    );

    // Get the offset point for an angle value of theta, and a distance of _radius
    Offset getOffsetForTheta(double theta, double radius) {
      return center +
          Offset(radius * math.cos(theta), -radius * math.sin(theta));
    }

    // Draw the handle that is used to drag and to indicate the position around the circle
    final handlePaint = Paint()..color = accentColor;
    final handlePoint = getOffsetForTheta(theta, radius * 0.9);
    canvas.drawCircle(handlePoint, 15.0, handlePaint);

    // Get the appropriate secondary unit string
    String getSecondaryUnitString() {
      switch (baseUnit) {
        case BaseUnit.millisecond:
          return 's ';
        case BaseUnit.second:
          return 'm ';
        case BaseUnit.minute:
          return 'h ';
        case BaseUnit.hour:
          return 'd ';
      }
    }

    String getUnitString() {
      switch (baseUnit) {
        case BaseUnit.millisecond:
          return 'ms ';
        case BaseUnit.second:
          return 's ';
        case BaseUnit.minute:
          return 'm ';
        case BaseUnit.hour:
          return 'h ';
      }
    }

    // Draw the Text in the center of the circle which displays the duration string
    final secondaryUnits = (baseUnitMultiplier == 0)
        ? ''
        : '$baseUnitMultiplier${getSecondaryUnitString()}';
    final baseUnits = '$baseUnitHand';

    final textDurationValuePainter = TextPainter(
      textAlign: TextAlign.center,
      text: TextSpan(
        text:
            '$secondaryUnits${baseUnits.padLeft(2, '0')} ${baseUnitMultiplier == 0 ? getUnitString() : ''}',
        style: labelStyle ??
            Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontSize: size.shortestSide * 0.15, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final middleForValueText = Offset(
      centerPoint.dx - (textDurationValuePainter.width / 2),
      centerPoint.dy - textDurationValuePainter.height / 2,
    );
    textDurationValuePainter.paint(canvas, middleForValueText);

    // Draw an arc around the circle for the amount of the circle that has elapsed.
    final elapsedPainter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = accentColor
      ..isAntiAlias = true
      ..strokeWidth = radius * 0.12;

    canvas.drawArc(
      Rect.fromCircle(
        center: centerPoint,
        radius: radius - radius * 0.12 / 2,
      ),
      startAngle,
      sweep * pctTheta,
      false,
      elapsedPainter,
    );
  }

  @override
  bool shouldRepaint(DialPainter oldDelegate) {
    return oldDelegate.circleColor != circleColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.theta != theta ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.selectedValue != selectedValue ||
        oldDelegate.pct != pct ||
        oldDelegate.baseUnitMultiplier != baseUnitMultiplier ||
        oldDelegate.baseUnitHand != baseUnitHand ||
        oldDelegate.baseUnit != baseUnit;
  }
}

class _Dial extends StatefulWidget {
  const _Dial({
    required this.duration,
    required this.onChanged,
    this.baseUnit = BaseUnit.minute,
    this.circleColor,
    this.labelStyle,
    this.progressColor,
    required this.backgroundColor,
  });

  final Color? circleColor;
  final Color? progressColor;
  final TextStyle? labelStyle;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final BaseUnit baseUnit;
  final Color backgroundColor;

  @override
  _DialState createState() => _DialState();
}

class _DialState extends State<_Dial> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _thetaController = AnimationController(
      duration: _kDialAnimateDuration,
      vsync: this,
    );
    _thetaTween = Tween<double>(
      begin: _getThetaForDuration(widget.duration, widget.baseUnit),
    );
    _theta = _thetaTween.animate(
      CurvedAnimation(parent: _thetaController, curve: Curves.fastOutSlowIn),
    )..addListener(() => setState(() {}));
    _thetaController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _secondaryUnitValue = _secondaryUnitHand();
        _baseUnitValue = _baseUnitHand();
        setState(() {});
      }
    });

    _turningAngle = _kPiByTwo - _turningAngleFactor() * _kTwoPi;
    _secondaryUnitValue = _secondaryUnitHand();
    _baseUnitValue = _baseUnitHand();
  }

  late ThemeData themeData;
  MaterialLocalizations? localizations;
  MediaQueryData? media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMediaQuery(context));
    themeData = Theme.of(context);
    localizations = MaterialLocalizations.of(context);
    media = MediaQuery.of(context);
  }

  @override
  void dispose() {
    _thetaController.dispose();
    super.dispose();
  }

  late Tween<double> _thetaTween;
  late Animation<double> _theta;
  late AnimationController _thetaController;

  final double _pct = 0.0;
  int _secondaryUnitValue = 0;
  bool _dragging = false;
  int _baseUnitValue = 0;
  double _turningAngle = 0.0;

  static double _nearest(double target, double a, double b) {
    return ((target - a).abs() < (target - b).abs()) ? a : b;
  }

  void _animateTo(double targetTheta) {
    final currentTheta = _theta.value;
    var beginTheta =
        _nearest(targetTheta, currentTheta, currentTheta + _kTwoPi);
    beginTheta = _nearest(targetTheta, beginTheta, currentTheta - _kTwoPi);
    _thetaTween
      ..begin = beginTheta
      ..end = targetTheta;
    _thetaController
      ..value = 0.0
      ..forward();
  }

  // Converts the duration to the chosen base unit. For example, for base unit minutes, this gets the number of minutes
  // in the duration
  int _getDurationInBaseUnits(Duration duration, BaseUnit baseUnit) {
    switch (baseUnit) {
      case BaseUnit.millisecond:
        return duration.inMilliseconds;
      case BaseUnit.second:
        return duration.inSeconds;
      case BaseUnit.minute:
        return duration.inMinutes;
      case BaseUnit.hour:
        return duration.inHours;
    }
  }

  // Converts the duration to the chosen secondary unit. For example, for base unit minutes, this gets the number
  // of hours in the duration
  int _getDurationInSecondaryUnits(Duration duration, BaseUnit baseUnit) {
    switch (baseUnit) {
      case BaseUnit.millisecond:
        return duration.inSeconds;
      case BaseUnit.second:
        return duration.inMinutes;
      case BaseUnit.minute:
        return duration.inHours;
      case BaseUnit.hour:
        return duration.inDays;
    }
  }

  // Gets the relation between the base unit and the secondary unit, which is the unit just greater than the base unit.
  // For example if the base unit is second, it will get the number of seconds in a minute
  int _getBaseUnitToSecondaryUnitFactor(BaseUnit baseUnit) {
    switch (baseUnit) {
      case BaseUnit.millisecond:
        return Duration.millisecondsPerSecond;
      case BaseUnit.second:
        return Duration.secondsPerMinute;
      case BaseUnit.minute:
        return Duration.minutesPerHour;
      case BaseUnit.hour:
        return Duration.hoursPerDay;
    }
  }

  double _getThetaForDuration(Duration duration, BaseUnit baseUnit) {
    final int baseUnits = _getDurationInBaseUnits(duration, baseUnit);
    final int baseToSecondaryFactor =
        _getBaseUnitToSecondaryUnitFactor(baseUnit);

    return (_kPiByTwo -
            (baseUnits % baseToSecondaryFactor) /
                baseToSecondaryFactor.toDouble() *
                _kTwoPi) %
        _kTwoPi;
  }

  double _turningAngleFactor() {
    return _getDurationInBaseUnits(widget.duration, widget.baseUnit) /
        _getBaseUnitToSecondaryUnitFactor(widget.baseUnit);
  }

  Duration _getTimeForTheta(double theta) {
    return _angleToDuration(_turningAngle);
  }

  Duration _notifyOnChangedIfNeeded() {
    _secondaryUnitValue = _secondaryUnitHand();
    _baseUnitValue = _baseUnitHand();
    final d = _angleToDuration(_turningAngle);
    widget.onChanged(d);

    return d;
  }

  void _updateThetaForPan() {
    setState(() {
      final offset = _position! - _center!;
      final angle = (math.atan2(offset.dx, offset.dy) - _kPiByTwo) % _kTwoPi;

      // Stop accidental abrupt pans from making the dial seem like it starts from 1h.
      // (happens when wanting to pan from 0 clockwise, but when doing so quickly, one actually pans from before 0 (e.g. setting the duration to 59mins, and then crossing 0, which would then mean 1h 1min).
      if (angle >= _kCircleTop &&
          _theta.value <= _kCircleTop &&
          _theta.value >= 0.1 && // to allow the radians sign change at 15mins.
          _secondaryUnitValue == 0) return;

      _thetaTween
        ..begin = angle
        ..end = angle;
    });
  }

  Offset? _position;
  Offset? _center;

  void _handlePanStart(DragStartDetails details) {
    assert(!_dragging);
    _dragging = true;
    final box = context.findRenderObject() as RenderBox?;
    _position = box?.globalToLocal(details.globalPosition);
    _center = box?.size.center(Offset.zero);

    _notifyOnChangedIfNeeded();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final oldTheta = _theta.value;
    _position = _position! + details.delta;
    // _position! += details.delta;
    _updateThetaForPan();
    final newTheta = _theta.value;

    _updateTurningAngle(oldTheta, newTheta);
    _notifyOnChangedIfNeeded();
  }

  int _secondaryUnitHand() {
    return _getDurationInSecondaryUnits(widget.duration, widget.baseUnit);
  }

  int _baseUnitHand() {
    // Result is in [0; num base units in secondary unit - 1], even if overall time is >= 1 secondary unit
    return _getDurationInBaseUnits(widget.duration, widget.baseUnit) %
        _getBaseUnitToSecondaryUnitFactor(widget.baseUnit);
  }

  Duration _angleToDuration(double angle) {
    return _baseUnitToDuration(_angleToBaseUnit(angle));
  }

  Duration _baseUnitToDuration(double baseUnitValue) {
    final int unitFactor = _getBaseUnitToSecondaryUnitFactor(widget.baseUnit);

    switch (widget.baseUnit) {
      case BaseUnit.millisecond:
        return Duration(
          seconds: baseUnitValue ~/ unitFactor,
          milliseconds: (baseUnitValue % unitFactor.toDouble()).toInt(),
        );
      case BaseUnit.second:
        return Duration(
          minutes: baseUnitValue ~/ unitFactor,
          seconds: (baseUnitValue % unitFactor.toDouble()).toInt(),
        );
      case BaseUnit.minute:
        return Duration(
          hours: baseUnitValue ~/ unitFactor,
          minutes: (baseUnitValue % unitFactor.toDouble()).toInt(),
        );
      case BaseUnit.hour:
        return Duration(
          days: baseUnitValue ~/ unitFactor,
          hours: (baseUnitValue % unitFactor.toDouble()).toInt(),
        );
    }
  }

  double _angleToBaseUnit(double angle) {
    // Coordinate transformation from mathematical COS to dial COS
    final dialAngle = _kPiByTwo - angle;

    // Turn dial angle into minutes, may go beyond 60 minutes (multiple turns)
    return dialAngle /
        _kTwoPi *
        _getBaseUnitToSecondaryUnitFactor(widget.baseUnit);
  }

  void _updateTurningAngle(double oldTheta, double newTheta) {
    // Register any angle by which the user has turned the dial.
    //
    // The resulting turning angle fully captures the state of the dial,
    // including multiple turns (= full hours). The [_turningAngle] is in
    // mathematical coordinate system, i.e. 3-o-clock position being zero, and
    // increasing counter clock wise.

    // From positive to negative (in mathematical COS)
    if (newTheta > 1.5 * math.pi && oldTheta < 0.5 * math.pi) {
      _turningAngle = _turningAngle - ((_kTwoPi - newTheta) + oldTheta);
    }
    // From negative to positive (in mathematical COS)
    else if (newTheta < 0.5 * math.pi && oldTheta > 1.5 * math.pi) {
      _turningAngle = _turningAngle + ((_kTwoPi - oldTheta) + newTheta);
    } else {
      _turningAngle = _turningAngle + (newTheta - oldTheta);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    assert(_dragging);
    _dragging = false;
    _position = null;
    _center = null;
    _animateTo(_getThetaForDuration(widget.duration, widget.baseUnit));
  }

  void _handleTapUp(TapUpDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    _position = box?.globalToLocal(details.globalPosition);
    _center = box?.size.center(Offset.zero);
    _updateThetaForPan();
    _notifyOnChangedIfNeeded();

    _animateTo(
      _getThetaForDuration(_getTimeForTheta(_theta.value), widget.baseUnit),
    );
    _dragging = false;
    _position = null;
    _center = null;
  }

  @override
  Widget build(BuildContext context) {
    int? selectedDialValue;

    _secondaryUnitValue = _secondaryUnitHand();
    _baseUnitValue = _baseUnitHand();

    return GestureDetector(
      excludeFromSemantics: true,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapUp: _handleTapUp,
      child: CustomPaint(
        painter: DialPainter(
          pct: _pct,
          baseUnitMultiplier: _secondaryUnitValue,
          baseUnitHand: _baseUnitValue,
          baseUnit: widget.baseUnit,
          context: context,
          selectedValue: selectedDialValue,
          circleColor: widget.circleColor,
          labelStyle: widget.labelStyle,
          accentColor: widget.progressColor!,
          theta: _theta.value,
          textDirection: Directionality.of(context),
          backgroundColor: widget.backgroundColor,
        ),
      ),
    );
  }
}

/// The [DurationPicker] widget.
class DurationTimePicker extends StatelessWidget {
  final Duration duration;
  final ValueChanged<Duration> onChange;
  final BaseUnit baseUnit;
  final EdgeInsetsGeometry? padding;
  final double? size;
  final Color? circleColor;
  final Color? progressColor;
  final TextStyle? labelStyle;
  final Color? backgroundColor;

  const DurationTimePicker(
      {Key? key,
      this.duration = Duration.zero,
      required this.onChange,
      this.baseUnit = BaseUnit.minute,
      this.padding,
      this.circleColor,
      this.labelStyle,
      this.progressColor,
      this.size,
      this.backgroundColor})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: padding ?? const EdgeInsets.all(20),
      width: size ?? _kDurationPickerWidthPortrait / 1.5,
      height: size ?? _kDurationPickerHeightPortrait / 1.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Dial(
              backgroundColor: backgroundColor ?? Theme.of(context).canvasColor,
              duration: duration,
              onChanged: onChange,
              baseUnit: baseUnit,
              labelStyle: labelStyle,
              progressColor: progressColor ?? Colors.yellow,
              circleColor: circleColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// This enum contains the possible units for the [DurationPicker]
enum BaseUnit {
  millisecond,
  second,
  minute,
  hour,
}
