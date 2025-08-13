using Toybox.Graphics as Gfx;
using Toybox.WatchUi as WatchUi;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Sensor as Sensor;
using Toybox.Lang as Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.ActivityMonitor;
using Toybox.Activity as Acty;
using Toybox.Weather;
using Toybox.StringUtil;

class FaceView extends WatchUi.WatchFace {

  var inLowPower = false;

  function onExitSleep() {
    inLowPower=false;
    WatchUi.requestUpdate();
  }

  function onEnterSleep() {
    inLowPower=true;
    WatchUi.requestUpdate();
  }

  function initialize() {
    WatchFace.initialize();
  }

  function drawIcon(dc, x, y, icon) {
    var bitmap = Application.loadResource(icon);
    dc.drawBitmap(x, y, bitmap);
  }

  function drawText(dc, x, y, text, font_name, scale, color, justification) {
    var fontOptions = {:font => font_name, :scale => scale};
    var font = Gfx.getVectorFont(fontOptions);
    dc.setColor(color, Gfx.COLOR_TRANSPARENT);
    dc.drawText(x, y, font, text, justification);
  }

  function checkNightMode(time) {
    var isNightMode = App.Properties.getValue("nightModeEnabled");
    return isNightMode && isNightNow(time);
  }

  function isNightNow(time) {
    var win = getNightWindow();
    var s = parseHHMM(win[:start]);
    var e = parseHHMM(win[:end]);

    var nowMin = time.hour*60 + time.min;
    var sMin = s[:h]*60 + s[:m];
    var eMin = e[:h]*60 + e[:m];

    return (sMin <= eMin) ? (nowMin >= sMin && nowMin < eMin)
                          : (nowMin >= sMin || nowMin < eMin);
  }

  function getPropStr(id, defValue) {
    var v = App.Properties.getValue(id);
    return (v == null) ? defValue : v;
  }

  function getNightWindow() as { :start as Lang.String, :end as Lang.String } {
    return {
        :start => getPropStr("StartNightTime", "23:00"),
        :end   => getPropStr("EndNightTime",   "07:00")
    };
  }

  function parseHHMM(s) as { :h as Lang.Number, :m as Lang.Number } {
    var def = { :h => 23, :m => 0 };
    if (s == null) {
      return def;
    }

    var colon = s.find(":");
    if (colon == null) {
      return def;
    }

    var hStr = s.substring(0, colon);
    var mStr = s.substring(colon + 1, null);

    if (hStr == null || mStr == null) {
      return def;
    }

    var h = (hStr.toNumber() or 23) % 24;
    var m = (mStr.toNumber() or 0) % 60;

    return { :h => h, :m => m };
  }

  function onUpdate(dc as Gfx.Dc) as Void {
    if (inLowPower == true) {
      return;
    }

    dc.clear();

    var centerX = dc.getWidth() / 2;
    var centerY = dc.getHeight() / 2;

    var radiusOuter = (dc.getWidth() / 2) - 1;
    var radiusInner = (dc.getWidth() / 2) - 17;

    var time = Sys.getClockTime();
    var night_mode = checkNightMode(time);

    if (night_mode) {
      drawAmPm(dc, time, centerX, centerY, night_mode);
      drawCenteredTime(dc, time, centerX, centerY, night_mode);
    } else {
      drawHourMarks(dc, centerX, centerY, radiusOuter);
      drawRadialHourNumbers(dc, centerX, centerY, radiusOuter - 1);
      drawGrid(dc, centerX, centerY, radiusInner);

      drawHourPointer(dc, time, centerX, centerY, radiusOuter);
      drawMinuteRing(dc, time, centerX, centerY, radiusInner);

      drawCenteredTime(dc, time, centerX, centerY, night_mode);
      drawSec(dc, time, centerX, centerY);
      drawAmPm(dc, time, centerX, centerY, night_mode);

      drawBatteryBar(dc, centerX, centerY);
      drawDateInfo(dc, centerX, centerY);
      drawSteps(dc, centerX, centerY);
      drawHeart(dc, centerX, centerY);
      drawBodyBattery(dc, centerX, centerY);
      drawCalories(dc, centerX, centerY);
      drawStress(dc, centerX, centerY);
      drawWeather(dc, centerX, centerY);
      drawConnection(dc, centerX, centerY);
      drawDistance(dc, centerX, centerY);
      drawAlarm(dc, centerX, centerY);
    }

    drawMessage(dc, centerX, centerY);
  }

  function drawHourMarks(dc, cx, cy, radius) {
    dc.setColor(0x909090, Gfx.COLOR_TRANSPARENT);

    for (var i = 1; i <= 12; i++) {
      for (var j = 1; j <= 4; j++) {
        var tickAngle = ((i - 1) * 30 + j * 6 - 90) * (Math.PI / 180);
        var tickStartX = cx + (radius - 10) * Math.cos(tickAngle);
        var tickStartY = cy + (radius - 10) * Math.sin(tickAngle);
        var tickEndX = cx + radius * Math.cos(tickAngle);
        var tickEndY = cy + radius * Math.sin(tickAngle);
        dc.drawLine(tickStartX, tickStartY, tickEndX, tickEndY);
      }
    }
  }

  function drawRadialHourNumbers(dc, cx, cy, radius) {
    var fontOptions = {:font => Gfx.FONT_SYSTEM_XTINY, :scale => 0.7};
    var font = Gfx.getVectorFont(fontOptions);
    dc.setColor(0xB0B0B0, Gfx.COLOR_TRANSPARENT);

    for (var i = 0; i < 12; i++) {
      var angle = (i * - 30) + 60;
      var number = i + 1;

      var inward = number == 10 || number == 11 || number == 12 || number == 1 || number == 2;
      var textRadius = inward ? (radius - 12) : radius;
      var direction = inward ? Gfx.RADIAL_TEXT_DIRECTION_CLOCKWISE : Gfx.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE;
    
      dc.drawRadialText(cx, cy, font, number.toString(), Gfx.TEXT_JUSTIFY_CENTER,
          angle, textRadius, direction);
    }
  }

  function drawGrid(dc, cx, cy, radius) {
    dc.setColor(0x909090, Gfx.COLOR_TRANSPARENT);

    var StartX = cx + 90;
    var EndX = cx - 90;
    var Y = cy - 140;
    dc.drawLine(StartX, Y, EndX, Y);
    Y = cy + 140;
    dc.drawLine(StartX, Y, EndX, Y);

    StartX = cx + 160;
    EndX = cx - 160;
    Y = cy - 45;
    dc.drawLine(StartX, Y, EndX, Y);
    Y = cy + 40;
    dc.drawLine(StartX, Y, EndX, Y);

    StartX = cx + 137;
    EndX = cx - 137;
    Y = cy - 95;
    dc.drawLine(StartX, Y, EndX, Y);
    Y = cy + 90;
    dc.drawLine(StartX, Y, EndX, Y);

    var StartY = cy - 45;
    var EndY = cy - 140;
    var X = cx;
    dc.drawLine(X, StartY, X, EndY);
    StartY = cy + 40;
    EndY = cy + 140;
    dc.drawLine(X, StartY, X, EndY);
  }

  function drawHourPointer(dc, time, cx, cy, radius) {
    var hour = time.hour % 12 + time.min / 60.0;
    var angle = (hour * 30 - 90) * (Math.PI / 180);

    var baseRadius = radius - 12;
    var pointerLength = 12;
    var pointerWidth = 10;

    var tipX = cx + (baseRadius + pointerLength) * Math.cos(angle);
    var tipY = cy + (baseRadius + pointerLength) * Math.sin(angle);

    var leftAngle = angle + Math.PI / 2;
    var rightAngle = angle - Math.PI / 2;

    var baseX = cx + baseRadius * Math.cos(angle);
    var baseY = cy + baseRadius * Math.sin(angle);

    var leftX = baseX + (pointerWidth / 2) * Math.cos(leftAngle);
    var leftY = baseY + (pointerWidth / 2) * Math.sin(leftAngle);

    var rightX = baseX + (pointerWidth / 2) * Math.cos(rightAngle);
    var rightY = baseY + (pointerWidth / 2) * Math.sin(rightAngle);

    dc.setColor(0xFF754A, Gfx.COLOR_TRANSPARENT);
    dc.fillPolygon([[tipX, tipY], [leftX, leftY], [rightX, rightY]]);
  }

  function drawMinuteRing(dc, time, cx, cy, radius) {
    var minutes = time.min.toFloat() + time.sec.toFloat() / 60;

    var angle = (minutes / 60.0) * -360.0 + 90;

    dc.setColor(0x12d383, Gfx.COLOR_TRANSPARENT);

    dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, 90.0, angle);
    dc.drawArc(cx, cy, radius-1, Gfx.ARC_CLOCKWISE, 90.0, angle);
    dc.drawArc(cx, cy, radius-2, Gfx.ARC_CLOCKWISE, 90.0, angle);
  }

  function drawCenteredTime(dc, time, cx, cy, night_mode) {
    var hours = time.hour;
    var minutes = time.min;

    if (!Sys.getDeviceSettings().is24Hour && hours > 12) {
        hours -= 12;
    }

    var time_text = hours.format("%02d") + ":" + minutes.format("%02d");
    var size = night_mode ? 1.4 : 0.9;

    drawText(dc, cx, cy, time_text, Gfx.FONT_SYSTEM_NUMBER_HOT, size, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawSec(dc, time, cx, cy) {
    var text = time.sec.format("%02d");
    drawText(dc, cx + 125, cy + 15, text, Gfx.FONT_SYSTEM_SMALL, 0.9, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawAmPm(dc, time, cx, cy, night_mode) {
    var text = time.hour > 12 ? "PM" : "AM";
    if (night_mode) {
      drawText(dc, cx, cy - 90, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
          Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    } else {
      drawText(dc, cx - 158, cy + 15, text, Gfx.FONT_SYSTEM_SMALL, 0.7, 0xC0C0C0,
          Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }
  }
  
  function drawBatteryBar(dc, cx, cy) {
    var battery = Math.floor(Sys.getSystemStats().battery);

    var battery_icon;
    
    if (battery >= 90) {
        battery_icon = Rez.Drawables.battery_100;
    } else if (battery >= 80) {
        battery_icon = Rez.Drawables.battery_90;
    } else if (battery >= 70) {
        battery_icon = Rez.Drawables.battery_80;
    } else if (battery >= 60) {
        battery_icon = Rez.Drawables.battery_70;
    } else if (battery >= 50) {
        battery_icon = Rez.Drawables.battery_60;
    } else if (battery >= 40) {
        battery_icon = Rez.Drawables.battery_50;
    } else if (battery >= 30) {
        battery_icon = Rez.Drawables.battery_40;
    } else if (battery >= 20) {
        battery_icon = Rez.Drawables.battery_30;
    } else if (battery >= 10) {
        battery_icon = Rez.Drawables.battery_20;
    } else {
        battery_icon = Rez.Drawables.battery_10;
    }

    drawIcon(dc, cx - 40, cy - 167, battery_icon);
    var text = battery.format("%d") + "%";
    drawText(dc, cx, cy - 155, text, Gfx.FONT_SYSTEM_TINY, 0.9, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawDateInfo(dc, cx, cy) {
    var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

    var lang = Sys.getDeviceSettings().systemLanguage;

    var daysRu = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
    var daysEn = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];

    var days = lang == Sys.LANGUAGE_RUS ? daysRu : daysEn;

    var text = today.day.format("%d") + " " + days[today.day_of_week - 1] + " " + today.month.format("%d");

    drawText(dc, cx - 10, cy - 70, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawSteps(dc, cx, cy) {
      var info = ActivityMonitor.getInfo();
  
      var text = info.steps != null ? info.steps.format("%d") : "––";
  
      var step_icon = Rez.Drawables.step;
      if (info.steps != null && info.stepGoal != null) {
        if (info.steps > info.stepGoal) {
          step_icon = Rez.Drawables.step_goal;
        }
      }

      drawIcon(dc, cx + 8, cy + 48, step_icon);
      drawText(dc, cx + 44, cy + 65, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawHeart(dc, cx, cy) {
    var heartRate = Acty.getActivityInfo().currentHeartRate;
    var text = heartRate != null ? heartRate.format("%d") : "––";

    var heart_icon = Rez.Drawables.heart_normal;
    if (heartRate != null) {
      if ( heartRate > 120) {
        heart_icon = Rez.Drawables.heart_warning;
      } else if ( heartRate > 160) {
        heart_icon = Rez.Drawables.heart_error;
      }
    }

    drawIcon(dc, cx + 5, cy + 101, heart_icon);
    drawText(dc, cx + 44, cy + 116, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function getBodyBatteryLevel() {
    var bodyBattery = null;

    var bodyBatteryHistory =
      Toybox.SensorHistory.getBodyBatteryHistory({:period => 2, :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST});
  
    var bodyBatterySample = bodyBatteryHistory.next();
    if (bodyBatterySample != null){
      bodyBattery = bodyBatterySample.data;
    } else {
      bodyBatterySample = bodyBatteryHistory.next();
    }
  
    if (bodyBatterySample != null){
      bodyBattery = bodyBatterySample.data;
    }

    return bodyBattery;
  }

  function drawBodyBattery(dc, cx, cy) {
    var bodyBattery = getBodyBatteryLevel();

    var text = bodyBattery != null ? bodyBattery.format("%d") : "––";
    var body_battery_icon = Rez.Drawables.body_battary_40;
  
    if (bodyBattery != null) {
      if (bodyBattery >= 80) {
        body_battery_icon = Rez.Drawables.body_battary_80;
      } else if (bodyBattery >= 60) {
        body_battery_icon = Rez.Drawables.body_battary_60;
      } else if (bodyBattery >= 30) {
        body_battery_icon = Rez.Drawables.body_battary_40;
      } else if (bodyBattery >= 10) {
        body_battery_icon = Rez.Drawables.body_battary_20;
      } else {
        body_battery_icon = Rez.Drawables.body_battary_0;
      }
    }

    drawIcon(dc, cx - 37, cy + 101, body_battery_icon);
    drawText(dc, cx - 44, cy + 116, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawCalories(dc, cx, cy) {
    var calories = ActivityMonitor.getInfo().calories;
    var text = calories != null ? calories.format("%d") : "––";

    drawIcon(dc, cx - 33, cy + 48, Rez.Drawables.cal);
    drawText(dc, cx - 44, cy + 65, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function getStressLevel() {
    var stress = null;

    var stressHistory =
          Toybox.SensorHistory.getStressHistory({:period => 2, :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST});
  
    var stressSample = stressHistory.next();
    if (stressSample != null){
      stress = stressSample.data;
    } else {
      stressSample = stressHistory.next();
    }

    if (stressSample != null){
      stress = stressSample.data;
    }

    return stress;
  }

  function drawStress(dc, cx, cy) {
    var stress = getStressLevel();
    var text = stress != null ? stress.format("%d") : "––";

    var stress_icon = Rez.Drawables.stress_40;
    if (stress != null) {
      if (stress >= 75) {
        stress_icon = Rez.Drawables.stress_80;
      } else if (stress >= 50) {
        stress_icon = Rez.Drawables.stress_60;
      } else if (stress >= 25) {
        stress_icon = Rez.Drawables.stress_40;
      } else {
        stress_icon = Rez.Drawables.stress_20;
      }
    }

    drawIcon(dc, cx + 15, cy - 132, stress_icon);
    drawText(dc, cx + 44, cy - 118, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawMessage(dc, cx, cy) {
    var NotificationCount = Sys.getDeviceSettings().notificationCount;
    var text = NotificationCount.format("%d");

    drawIcon(dc, cx - 30, cy + 148, Rez.Drawables.message);
    drawText(dc, cx + 8, cy + 158, text, Gfx.FONT_SYSTEM_TINY, 0.9, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawWeather(dc, cx, cy) {
    var currentConditions = Weather.getCurrentConditions();

    var tempereture = currentConditions != null ? currentConditions.temperature : null;
    var temperature_units = Sys.getDeviceSettings().temperatureUnits;

    var degree = StringUtil.utf8ArrayToString([0xC2,0xB0]);

    var text;
    if (temperature_units == Sys.UNIT_METRIC) {
      text = tempereture != null ? tempereture.format("%d") + degree + "C" : "––" + degree + "C";
    } else {
      tempereture = (tempereture * 9/5) + 32;
      text = tempereture != null ? tempereture.format("%d") + degree + "F" : "––" + degree + "F";
    }

    drawText(dc, cx - 10, cy - 118, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawDistance(dc, cx, cy) {
    var distance = ActivityMonitor.getInfo().distance;
    var distance_units = Sys.getDeviceSettings().distanceUnits;

    var text;
    if (distance_units == Sys.UNIT_METRIC) {
      if (distance != null){
        var distance_km = distance.toFloat() / 100.0 / 1000.0;
        if (distance_km < 10.0) {
          text = distance_km.format("%.1f") + "km";
        }else {
          text = distance_km.format("%.0f") + "km";
        }
      } else {
        text = "––km";
      }
    } else {
      if (distance != null){
        var distance_miles = distance / 100.0 * 0.000621371;
        if (distance_miles < 10.0) {
          text = distance_miles.format("%.1f") + "mi";
        }else {
          text = distance_miles.format("%.0f") + "mi";
        }
      } else {
        text = "––mi";
      }
    }

    drawIcon(dc, cx + 8, cy - 83, Rez.Drawables.distance);
    drawText(dc, cx + 44, cy - 70, text, Gfx.FONT_SYSTEM_SMALL, 1.0, 0xC0C0C0,
        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
  }

  function drawConnection(dc, cx, cy) {
    var connection = Sys.getDeviceSettings().phoneConnected;

    if (connection == true) {
      drawIcon(dc, cx - 150, cy - 35, Rez.Drawables.bluetooth);
    }
  }

  function drawAlarm(dc, cx, cy) {
    var alarmCount = Sys.getDeviceSettings().alarmCount;

    if (alarmCount > 0) {
      drawIcon(dc, cx + 130, cy - 36, Rez.Drawables.alarm);
    }
  }
}

