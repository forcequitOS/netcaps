### 1, 2, 3, efficiency!
This revision to netcaps is a legitimately dramatic improvement for memory efficiency (and a few little enhancements for better CPU efficiency, too), with some minor tweaks to how network activity is determined. Let's take a look. 

- Filters out unimportant/duplicate network addresses, if there's any common and important ones for network activity that I missed in my whitelist, let me know. This should mean that having Wi-Fi off really will mean the indicator is 100% off (even if communication is happening to the loopback address), and that stuff like peer-to-peer communications over AirDrop can be seen easier.
- The actual Caps Lock LED toggling stuff is handled by a class now, which allows for IOHIDManager to be reused between toggles, rather than generating a new one every single time (Which was really rough on memory before), this is probably the largest improvement.
- When network activity is idle for enough checks, a delay is added to reduce the number of CPU cycles used, it's still plenty responsive enough for actual usage.

That's really about it! Enjoy 1.5.0!