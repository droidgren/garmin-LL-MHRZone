import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.WatchUi;

class LastLapMaxHRZoneView extends WatchUi.DataField {

    // Maximum HR observed during the current lap
    hidden var mCurrentLapMaxHR as Number = 0;

    // The computed max HR zone for the last completed lap
    hidden var mLastLapMaxZone as Float or Null = null;
    hidden var mDisplayText as String = "--";

    function initialize() {
        DataField.initialize();
    }

    // Called when the user presses the lap button (manual or auto-lap)
    function onTimerLap() as Void {
        if (mCurrentLapMaxHR > 0) {
            mLastLapMaxZone = computeHRZone(mCurrentLapMaxHR.toFloat());
            mDisplayText = (mLastLapMaxZone as Float).format("%.1f");
        }
        // Reset for the new lap
        mCurrentLapMaxHR = 0;
    }

    // Calculate the decimal HR zone for a given heart rate.
    // Returns a float like 3.4 meaning "40% through zone 3".
    hidden function computeHRZone(hr as Float) as Float {
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones == null || zones.size() < 2) {
            return 0.0f;
        }

        var numZones = zones.size() - 1;

        // Below zone 1
        if (hr < zones[0]) {
            // Return a proportional value between 0 and 1
            if (zones[0] > 0) {
                return hr / zones[0].toFloat();
            }
            return 0.0f;
        }

        // Find the zone the HR falls into
        for (var i = 0; i < numZones; i++) {
            var zoneLow = zones[i].toFloat();
            var zoneHigh = zones[i + 1].toFloat();
            if (hr >= zoneLow && hr < zoneHigh) {
                var fraction = (hr - zoneLow) / (zoneHigh - zoneLow);
                return (i + 1) + fraction;
            }
        }

        // At or above the top of the highest zone
        return numZones.toFloat();
    }

    // Called once per second during an activity
    function compute(info as Activity.Info) as Void {
        // Track the maximum HR sample for the current lap
        if (info has :currentHeartRate && info.currentHeartRate != null) {
            var hr = info.currentHeartRate as Number;
            if (hr > mCurrentLapMaxHR) {
                mCurrentLapMaxHR = hr;
            }
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var backgroundColor = getBackgroundColor();
        var defaultTextColor = getDefaultTextColor(backgroundColor);

        dc.setColor(defaultTextColor, backgroundColor);
        dc.clear();

        var valueColor = defaultTextColor;
        if (isZoneColorEnabled() && mLastLapMaxZone != null) {
            valueColor = getZoneColor(mLastLapMaxZone as Float, backgroundColor);
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var showLabel = height >= 40;
        var labelFont = Graphics.FONT_XTINY;
        var valueFont = getValueFont(height);
        var labelHeight = showLabel ? dc.getFontHeight(labelFont) : 0;
        var valueY = showLabel ? ((height + labelHeight) / 2) : (height / 2);

        if (showLabel) {
            dc.setColor(defaultTextColor, backgroundColor);
            dc.drawText(width / 2, 0, labelFont, "LL Max HRZ", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(valueColor, backgroundColor);
        dc.drawText(width / 2, valueY, valueFont, mDisplayText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Reset everything when the timer is reset
    function onTimerReset() as Void {
        mCurrentLapMaxHR = 0;
        mLastLapMaxZone = null;
        mDisplayText = "--";
    }

    hidden function getValueFont(fieldHeight as Number) as Graphics.FontType {
        if (fieldHeight >= 84) {
            return Graphics.FONT_LARGE;
        } else if (fieldHeight >= 56) {
            return Graphics.FONT_MEDIUM;
        }

        return Graphics.FONT_SMALL;
    }

    hidden function isZoneColorEnabled() as Boolean {
        try {
            var value = Application.Properties.getValue("zone_color_digits");
            if (value != null) {
                return value as Boolean;
            }
        } catch (e) {
        }

        return true;
    }

    hidden function getDefaultTextColor(backgroundColor as Graphics.ColorType) as Graphics.ColorType {
        if (backgroundColor == Graphics.COLOR_BLACK) {
            return Graphics.COLOR_WHITE;
        }

        return Graphics.COLOR_BLACK;
    }

    // Garmin-style zones: 1 gray, 2 blue, 3 green, 4 orange, 5 red
    hidden function getZoneColor(zone as Float, backgroundColor as Graphics.ColorType) as Graphics.ColorType {
        if (zone < 2.0f) {
            return (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        } else if (zone < 3.0f) {
            return Graphics.COLOR_BLUE;
        } else if (zone < 4.0f) {
            return Graphics.COLOR_GREEN;
        } else if (zone < 5.0f) {
            return Graphics.COLOR_ORANGE;
        }

        return Graphics.COLOR_RED;
    }

}
