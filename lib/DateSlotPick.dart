library flutter_datetime_picker;

import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/src/datetime_picker_theme.dart';
import 'package:flutter_datetime_picker/src/date_model.dart';
import 'package:flutter_datetime_picker/src/i18n_model.dart';

export 'package:flutter_datetime_picker/src/datetime_picker_theme.dart';
export 'package:flutter_datetime_picker/src/date_model.dart';
export 'package:flutter_datetime_picker/src/i18n_model.dart';

typedef DateChangedCallback(DateTime time);
typedef DateCancelledCallback();
typedef String StringAtIndexCallBack(int index);
typedef int StringAtIndexCallBackSelect();
typedef DateResultCallback(String startTime, String endTime);

class DateSlotPick {
  ///
  /// Display date picker bottom sheet.
  ///
  static Future<DateTime> showDatePicker(
    BuildContext context, {
    bool showTitleActions: true,
    DateTime minTime,
    DateTime maxTime,
    DateChangedCallback onChanged,
    DateResultCallback onConfirm,
    DateCancelledCallback onCancel,
    locale: LocaleType.en,
    DateTime currentTime,
    DatePickerTheme theme,
  }) async {
    return await Navigator.push(
      context,
      _DatePickerRoute(
        showTitleActions: showTitleActions,
        onChanged: onChanged,
        onConfirm: onConfirm,
        onCancel: onCancel,
        locale: locale,
        theme: theme,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        pickerModel: DatePickerModel(
          currentTime: currentTime,
          maxTime: maxTime,
          minTime: minTime,
          locale: locale,
        ),
      ),
    );
  }
}

class _DatePickerRoute<T> extends PopupRoute<T> {
  _DatePickerRoute({
    this.showTitleActions,
    this.onChanged,
    this.onConfirm,
    this.onCancel,
    theme,
    this.barrierLabel,
    this.locale,
    RouteSettings settings,
    pickerModel,
  })  : this.pickerModel = pickerModel ?? DatePickerModel(),
        this.theme = theme ?? DatePickerTheme(),
        super(settings: settings);

  final bool showTitleActions;
  final DateChangedCallback onChanged;
  final DateResultCallback onConfirm;
  final DateCancelledCallback onCancel;
  final DatePickerTheme theme;
  final LocaleType locale;
  final BasePickerModel pickerModel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  bool get barrierDismissible => true;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => Colors.black54;

  AnimationController _animationController;

  @override
  AnimationController createAnimationController() {
    assert(_animationController == null);
    _animationController =
        BottomSheet.createAnimationController(navigator.overlay);
    return _animationController;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    Widget bottomSheet = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: _DatePickerComponent(
        onChanged: onChanged,
        locale: this.locale,
        route: this,
        pickerModel: pickerModel,
      ),
    );
    return InheritedTheme.captureAll(context, bottomSheet);
  }
}

class _DatePickerComponent extends StatefulWidget {
  // final defaultDataFormat = new DateFormat("yyyy:MM:dd");
  _DatePickerComponent({
    Key key,
    @required this.route,
    this.onChanged,
    this.locale,
    this.pickerModel,
  }) : super(key: key);

  final DateChangedCallback onChanged;

  final _DatePickerRoute route;

  final LocaleType locale;

  BasePickerModel pickerModel;

  @override
  State<StatefulWidget> createState() {
    return _DatePickerState();
  }
}

class _DatePickerState extends State<_DatePickerComponent> {
  FixedExtentScrollController leftScrollCtrl, middleScrollCtrl, rightScrollCtrl;

  DateTime startDate;
  DateTime endDate;

  //DateTime tempDate;

  //CommonPickerModel _pickerModel;

  int type = 0;

  @override
  void initState() {
    super.initState();
    refreshScrollOffset();
  }

  void refreshScrollOffset() {
//    print('refreshScrollOffset ${widget.pickerModel.currentRightIndex()}');
    leftScrollCtrl = FixedExtentScrollController(
        initialItem: widget.pickerModel.currentLeftIndex());
    middleScrollCtrl = FixedExtentScrollController(
        initialItem: widget.pickerModel.currentMiddleIndex());
    rightScrollCtrl = FixedExtentScrollController(
        initialItem: widget.pickerModel.currentRightIndex());
  }

  @override
  Widget build(BuildContext context) {
    DatePickerTheme theme = widget.route.theme;
    return GestureDetector(
      child: AnimatedBuilder(
        animation: widget.route.animation,
        builder: (BuildContext context, Widget child) {
          final double bottomPadding = MediaQuery.of(context).padding.bottom;
          return ClipRect(
            child: CustomSingleChildLayout(
              delegate: _BottomPickerLayout(
                widget.route.animation.value,
                theme,
                showTitleActions: widget.route.showTitleActions,
                bottomPadding: bottomPadding,
              ),
              child: GestureDetector(
                child: Material(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8)),
                  color: theme.backgroundColor ?? Colors.white,
                  child: _renderPickerView(theme),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _notifyDateChanged() {
    if (widget.onChanged != null) {
      widget.onChanged(widget.pickerModel.finalTime());
    }
    if (type == 0) {
      startDate = widget.pickerModel.finalTime();
    } else {
      endDate = widget.pickerModel.finalTime();
    }
  }

  Widget _renderPickerView(DatePickerTheme theme) {
    Widget itemView = _renderItemView(theme);
    if (widget.route.showTitleActions) {
      return Column(
        children: <Widget>[
          _RederTitleShow(theme),
          itemView,
          _renderTitleActionsView(theme),
        ],
      );
    }
    return itemView;
  }

  Widget _renderColumnView(
    ValueKey key,
    DatePickerTheme theme,
    StringAtIndexCallBack stringAtIndexCB,
    StringAtIndexCallBackSelect boolSelect,
    ScrollController scrollController,
    int layoutProportion,
    ValueChanged<int> selectedChangedWhenScrolling,
    ValueChanged<int> selectedChangedWhenScrollEnd,
  ) {
    return Expanded(
      flex: layoutProportion,
      child: Container(
        padding: EdgeInsets.all(8.0),
        height: theme.containerHeight,
        decoration: BoxDecoration(color: theme.backgroundColor ?? Colors.white),
        child: NotificationListener(
          onNotification: (ScrollNotification notification) {
            if (notification.depth == 0 &&
                selectedChangedWhenScrollEnd != null &&
                notification is ScrollEndNotification &&
                notification.metrics is FixedExtentMetrics) {
              final FixedExtentMetrics metrics = notification.metrics;
              final int currentItemIndex = metrics.itemIndex;
              selectedChangedWhenScrollEnd(currentItemIndex);
            }
            return false;
          },
          child: CupertinoPicker.builder(
            key: key,
            backgroundColor: theme.backgroundColor ?? Colors.white,
            scrollController: scrollController,
            itemExtent: theme.itemHeight,
            onSelectedItemChanged: (int index) {
              selectedChangedWhenScrolling(index);
            },
            useMagnifier: true,
            itemBuilder: (BuildContext context, int index) {
              final content = stringAtIndexCB(index);
              var isSelect = boolSelect() == index;
              if (isSelect == null) {
                isSelect = false;
              }
              if (content == null) {
                return null;
              }

              return Container(
                height: theme.itemHeight,
                alignment: Alignment.center,
                child: Text(
                  content,
                  style: isSelect
                      ? theme.itemStyle
                      : TextStyle(
                          color: Colors.grey,
                          fontSize: theme.itemStyle.fontSize),
                  textAlign: TextAlign.start,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _renderItemView(DatePickerTheme theme) {
    return Container(
      color: theme.backgroundColor ?? Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            child: widget.pickerModel.layoutProportions()[0] > 0
                ? _renderColumnView(
                    ValueKey(widget.pickerModel.currentLeftIndex()),
                    theme,
                    widget.pickerModel.leftStringAtIndex,
                    widget.pickerModel.currentLeftIndex,
                    leftScrollCtrl,
                    widget.pickerModel.layoutProportions()[0], (index) {
                    widget.pickerModel.setLeftIndex(index);
                  }, (index) {
                    setState(() {
                      refreshScrollOffset();
                      _notifyDateChanged();
                    });
                  })
                : null,
          ),
          Text(
            widget.pickerModel.leftDivider(),
            style: theme.itemStyle,
          ),
          Container(
            child: widget.pickerModel.layoutProportions()[1] > 0
                ? _renderColumnView(
                    ValueKey(widget.pickerModel.currentLeftIndex()),
                    theme,
                    widget.pickerModel.middleStringAtIndex,
                    widget.pickerModel.currentMiddleIndex,
                    middleScrollCtrl,
                    widget.pickerModel.layoutProportions()[1], (index) {
                    widget.pickerModel.setMiddleIndex(index);
                  }, (index) {
                    setState(() {
                      refreshScrollOffset();
                      _notifyDateChanged();
                    });
                  })
                : null,
          ),
          Text(
            widget.pickerModel.rightDivider(),
            style: theme.itemStyle,
          ),
          Container(
            child: widget.pickerModel.layoutProportions()[2] > 0
                ? _renderColumnView(
                    ValueKey(widget.pickerModel.currentMiddleIndex() * 100 +
                        widget.pickerModel.currentLeftIndex()),
                    theme,
                    widget.pickerModel.rightStringAtIndex,
                    widget.pickerModel.currentRightIndex,
                    rightScrollCtrl,
                    widget.pickerModel.layoutProportions()[2], (index) {
                    widget.pickerModel.setRightIndex(index);
                  }, (index) {
                    setState(() {
                      refreshScrollOffset();
                      _notifyDateChanged();
                    });
                  })
                : null,
          ),
        ],
      ),
    );
  }

  Widget _RederTitleShow(
    DatePickerTheme theme,
  ) {
    return Container(
      child: Column(
        children: [
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  alignment: Alignment.center,
                  height: theme.titleHeight,
                  child: Text(
                    '自定义时段',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: theme.itemStyle.height,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    /// print("qux ");
                    Navigator.pop(context);
                  },
                  child: Container(
                    child: Icon(
                      Icons.close,
                    ),
                  ),
                )
              ],
            ),
          ),
          Divider(
            color: Colors.grey,
            height: 0.5,
          ),
          Container(
            color: theme.itemStyle.backgroundColor,
            margin: EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: Color(0xFFF3F6FA),
                borderRadius: BorderRadius.all(Radius.circular(2))),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  alignment: Alignment.center,
                  height: 30,
                  width: 80,
                  // margin: EdgeInsets.only(left: 10, right: 8),
                  child: Text(
                    "查询时间",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: theme.itemStyle.fontSize * 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                      onTap: () {
                        setState(() {
                          type = 0;
                        });
                        if (startDate != null) {
                          setState(() {
                            widget.pickerModel = DatePickerModel(
                                maxTime: DateTime.now(),
                                minTime: DateTime(2016, 1, 1),
                                currentTime: startDate,
                                locale: LocaleType.zh);
                          });
                        }
                      },
                      child: Container(
                          alignment: Alignment.center,
                          height: 25,
                          width: 80,
                          // margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              border: Border.all(
                                color: type == 0
                                    ? Colors.orangeAccent
                                    : Colors.grey,
                                width: 1,
                              ),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(3))),
                          child: Text(
                            startDate == null
                                ? ""
                                : startDate.toIso8601String().split("T")[0],
                            style: TextStyle(
                              color: Color(0xff276cfe),
                              fontSize: theme.itemStyle.fontSize * 0.9,
                            ),
                          ))),
                ),
                Container(
                  alignment: Alignment.center,
                  height: 30,
                  width: 20,
                  //margin: EdgeInsets.only(left: 8, right: 8),
                  child: Text(
                    "-",
                    style: TextStyle(
                      color: Color(0xff005566),
                      fontSize: theme.itemStyle.fontSize * 0.6,
                    ),
                  ),
                ),
                Expanded(
                    child: GestureDetector(
                        onTap: () {
                          setState(() {
                            type = 1;
                            if (startDate != null && endDate == null) {
                              widget.pickerModel = DatePickerModel(
                                  maxTime: DateTime.now(),
                                  minTime: startDate,
                                  currentTime: startDate,
                                  locale: LocaleType.zh);
                            } else if (startDate != null && endDate != null) {
                              widget.pickerModel = DatePickerModel(
                                  maxTime: DateTime.now(),
                                  minTime: startDate,
                                  currentTime: endDate,
                                  locale: LocaleType.zh);
                            }
                          });
                        },
                        child: Container(
                            alignment: Alignment.center,
                            height: 25,
                            width: 100,
                            margin: EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                                border: Border.all(
                                  color: type != 0
                                      ? Colors.orangeAccent
                                      : Colors.grey,
                                  width: 1,
                                ),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(3))),
                            child: Text(
                              endDate == null
                                  ? ""
                                  : endDate.toIso8601String().split("T")[0],
                              style: TextStyle(
                                color: Color(0xff276cfe),
                                fontSize: theme.itemStyle.fontSize * 0.9,
                              ),
                            )))),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Widget _rederBottomButon(DatePickerTheme theme){
  //   final done = _localeDone();
  //   final cancel = _localeCancel();
  //
  // }

  // Title View
  Widget _renderTitleActionsView(DatePickerTheme theme) {
    final done = _localeDone();
    final cancel = _localeCancel();

    return Container(
      height: theme.titleHeight,
      decoration: BoxDecoration(
        color: theme.headerColor ?? theme.backgroundColor ?? Colors.white,
      ),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.,
        children: <Widget>[
          Expanded(
            child: Container(
              color: Color(0xffe9f3ff),
              height: theme.titleHeight,
              child: CupertinoButton(
                pressedOpacity: 0.3,
                color: theme.cancelStyle.backgroundColor,
                padding: EdgeInsets.all(6),
                child: Text(
                  '$cancel',
                  style: TextStyle(color: Color(0xff2167fd), fontSize: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.route.onCancel != null) {
                    widget.route.onCancel();
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Color(0xff276cfe),
              height: theme.titleHeight,
              child: CupertinoButton(
                pressedOpacity: 0.3,
                padding: EdgeInsets.all(6),
                child: Text(
                  '$done',
                  style: theme.doneStyle,
                ),
                onPressed: () {
                  if (startDate != null && endDate != null) {
                    //context.
                    Navigator.pop(context, widget.pickerModel.finalTime());
                  }
                  if (widget.route.onConfirm != null) {
                    widget.route.onConfirm(
                        startDate.toIso8601String().split("T").first,
                        endDate.toIso8601String().split("T").first);
                  }
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  String _localeDone() {
    return i18nObjInLocale(widget.locale)['done'];
  }

  String _localeCancel() {
    return i18nObjInLocale(widget.locale)['cancel'];
  }
}

class _BottomPickerLayout extends SingleChildLayoutDelegate {
  _BottomPickerLayout(
    this.progress,
    this.theme, {
    this.itemCount,
    this.showTitleActions,
    this.bottomPadding = 0,
  });

  final double progress;
  final int itemCount;
  final bool showTitleActions;
  final DatePickerTheme theme;
  final double bottomPadding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    double maxHeight = theme.containerHeight;
    if (showTitleActions) {
      maxHeight += theme.titleHeight * 3 - 3.1;
    }

    return BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      minHeight: 0.0,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final height = size.height - childSize.height * progress;
    //MediaQuery.of(c)

    return Offset(0.0, height * 0.5);
  }

  @override
  bool shouldRelayout(_BottomPickerLayout oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
