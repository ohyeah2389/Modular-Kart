This is the repository for my Modular Kart Class 2 vehicle for Assetto Corsa. 
It is a work-in-progress in its physics and graphics, and is not complete or fully representative of a real kart, but I hope it will still be enjoyable to use.
Every single component of this kart for AC has been written, configured, modeled, recorded, or generated from scratch by me (with some occasional help from some of the members (Arch, JPG_18, etc.) of the CSP Discord server for things like tire model tweaks and miscellaneous physics advice, as well as using some utilities written by the user Arch). 
No part of this kart mod has been sourced from anywhere other than the template car distributed with Assetto Corsa by Kunos.
If you have any questions, comments, suggestions, or notes that you'd like to share with me, you can use this repository's Issues or Pull Request features, or you can contact me on Discord @ohyeah2389.

-ohyeah2389

### Introduction:

This is my attempt to bring the world of professional/outdoor/owner kart racing to Assetto Corsa at a higher fidelity than has been accomplished before. Assetto Corsa is famously a car racing/driving sim, but with the physics extensions provided by the popular Custom Shaders Patch physics and graphics extension, I do now believe that karts are possible to simulate with it.

I've been working for the past few months on a completely scratch-built implementation of a 1050mm-wheelbase sprint kart as is popular in the US, Australia, and Europe for all levels of competition from club events to world championships. The kart will eventually be outfitted with a few different engine types, such as the four-stroke LO206 which is popular in the US, and the IAME X30 water-cooled two-stroke, but I'll be starting with the IAME KA100 air-cooled two-stroke engine, which is popular worldwide on all levels of competition.

Please read the LICENSE file for information on the license this code is provided to you under. Attribution must be given to the original creator (ohyeah2389) wherever it is posted or used. No commercial use is allowed (for example, no putting this kart model or any derivatives of it or its components on a pay-for-use simulator, and no using it or any derivatives of it or its components as part of a training program for a for-profit race team).

### Installation:

You should be able to drag-n-drop this downloaded zip file onto Content Manager and install it that way. Manual installation is also possible and recommended if you are comfortable with doing that.
If you are installing an update, please select "Clean installation" in the installation type dropdown in Content Manager's install window. Be aware that this will probably wipe your skins folder upon reinstallation of the kart.
If this process leads to any unexpected behavior, please let me know-- Content Manager's automatic installation of mods can often cause issues, especially with mods that are not formatted traditionally like this one.

### Features:

Karts operate very differently from how cars operate, and this is also true of this kart in AC. Here are some of the key elements that are different from basically every other mod you may have used for AC before:

🟩 The engine can stall. This is due to the fully custom engine model reimplementation I have written in Lua that the kart utilizes. The kart will spawn in with the engine off. To start it, hold the "Extra A" button (bindable in Content Manager under the "Patch" category) as you would with the engine start button on a real IAME KA100. The engine can also be killed by holding the ignition kill switch, which is bound the the "Extra B" button.

🟩 There is no gearbox. The kart doesn't have a gearbox in real life, much less a reverse gear, so the kart in-game is locked to always be in first. To get around the issue of getting stuck in a corner when you would normally be able to use reverse to free yourself, the shift buttons have been repurposed into force application controls. These allow you to apply a force to the kart (forwards with upshift and backwards with downshift) to move your kart around. They deactivate at 10 km/h, so you can't use them for an extra speed boost on the straights.

🟩 There is no clutch. Well, there is a clutch, but it is automatically operated by centrifugal forces from the crankshaft's spin. Pushing the clutch pedal should do nothing. It's a slightly more complicated implementation than the autoclutch system in the stock game, so it might have some weirdness, but it should overall work better and more realistically than the autoclutch system.

🟩 There is no suspension. Karts just don't have any springs or dampers to soften the ride. However, this doesn't mean there isn't any flex or bounce in the chassis or tires. The tires have some vertical give to them, and the chassis can flex in a few axes, along with the rear axle. This is the main quirk that seperates the driving experience of a kart from that of a car, and its consequences are realistically represented here, as the kart does flex and bounce in-sim, hopefully like a real kart does.

🟩 The engine is tunable. High and low speed jets can be tuned using controls bindable via the Extended Controls app (available from the CSP App Shelf). Fancy UI will be coming later, but for now you can monitor the setting of the jets and the engine component temperatures via the CSP Lua Debug app under the Car Physics script view. Temperatures aren't relevant just yet; aim for a air/fuel ratio of 14.7 on-throttle for maximum engine performance. In the future though, engine thermals will have an effect-- you might even be able to seize your engine if you let them get too high for too long.

🟨 **CAUTION:** The grip level of the track works differently now to how it works with most if not all other vehicles in AC: 90% grip should be a good value for a moderately rubbered track. 95% represents a heavily rubbered track. **100% is an extremely rubbered track that might be very difficult to drive on and to make a setup for.** Please check your grip level settings if using the kart in singleplayer.

🟥 **WARNING:** The custom suspension kinematics system, at least how I've configured it, is very jittery at low speeds (<8mph)! You should probably turn your force feedback down before you learn how and when this bug manifests itself. I am looking for the direct cause of this to see if I can fix it, but I haven't found it yet.

🟨 **CAUTION:** You should **NOT** set up your wheel to use Real Feel in the CSP settings (under FFB Tweaks). As mentioned above, the COSMIC suspension system, on this small scale, causes jitters at low speeds which transfer to the FFB system. I have a system in place to mitigate this, but it is deactivated if the Real Feel option is enabled.

🟥 **WARNING:** This kart mod is VERY unfinished in many aspects. Large parts of the visual model are missing (drivetrain, etc.) The sounds are also very rough and will likely be redone and expanded-- if not replaced by real recordings.

