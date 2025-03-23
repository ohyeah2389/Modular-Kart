![Modular Kart logo](https://github.com/ohyeah2389/Modular-Kart/blob/main/Graphics/modular_kart.png?raw=true)

This is the repository for my Modular Kart Class 2 vehicle for Assetto Corsa. 
It is a work-in-progress in its physics and graphics, and is not complete or fully representative of a real kart, but I hope it will still be enjoyable to use.
Every single component of this kart for AC has been written, configured, modeled, recorded, or generated from scratch by me (with some occasional help from some of the members (Arch, JPG_18, highrola, etc.) of the CSP Discord server for things like tire model tweaks and miscellaneous physics advice, as well as using some utilities written by the user Arch). 
No part of this kart mod has been sourced from anywhere other than the template car distributed with Assetto Corsa by Kunos.
If you have any questions, comments, suggestions, or notes that you'd like to share with me, you can use this repository's Issues or Pull Request features, or you can contact me on Discord @ohyeah2389.

-ohyeah2389

## Introduction:

This is my attempt to bring the world of professional/outdoor/owner kart racing to Assetto Corsa at a higher fidelity than has been accomplished before. Assetto Corsa is famously a car racing/driving sim, but with the physics extensions provided by the popular Custom Shaders Patch physics and graphics extension, I do now believe that karts are possible to simulate with it.

I've been working for the past few months on this completely scratch-built implementation of a 1050mm-wheelbase sprint kart as is popular in the US, Australia, and Europe for all levels of competition from club events to world championships. This kart will eventually be outfitted with a few different engine types, such as the four-stroke LO206 which is popular in the US, and the IAME X30 water-cooled two-stroke, but I'll be focusing on the IAME KA100 air-cooled two-stroke engine, which is popular worldwide on all levels of competition. I have included two other engine physics models for testing purposes, but they don't have their own 3D models yet, and won't until the KA100 model is finished.

Please read the LICENSE file for information on the license this code is provided to you under. Attribution must be given to the original creator (ohyeah2389) wherever it is posted or used. No commercial use is allowed (for example, no putting this kart model or any derivatives of it or its components on a pay-for-use simulator, and no using it or any derivatives of it or its components as part of a training program for a for-profit race team). While this repository is provided under the license listed, take note that the art assets are not present in this repository and are not licensed under the same terms. Conversion, ripping, or use of the art assets in any way other than intended (including conversion for other games or non-game uses) goes against the terms of the license of the compiled releases and is not legal without prior, explicit, written permission.

## Requirements:

- A legal copy of Assetto Corsa
- Custom Shaders Patch v0.2.6 or later installed and configured properly (see warnings below)

## Installation:

Download the zip file from the latest release in the Releases section of this repository. You should be able to drag-n-drop the downloaded zip file onto Content Manager and install it that way. Manual installation is also possible and recommended if you are comfortable with doing that.
If you are installing an update, please select "Clean installation" in the installation type dropdown in Content Manager's install window. Be aware that this will probably wipe your skins folder upon reinstallation of the kart.
If this process leads to any unexpected behavior, please let me know-- Content Manager's automatic installation of mods can often cause issues, especially with mods that are not formatted traditionally like this one.

## Features:

Karts operate very differently from how cars operate, and this is also true of this kart in AC. Here are some of the key elements that are different from basically every other mod you may have used for AC before:

🟥 **WARNING:** The custom suspension kinematics system, at least how I've configured it, is very jittery under certain conditions. You should probably turn your force feedback down before you learn how and when this bug manifests itself. This is likely due to the low physics update rate of Assetto Corsa combined with the stiff chassis flex simulation. I've added some dampers to try to limit its effect, but they're not perfect yet. You should **NOT** set up your wheel to use Real Feel in the CSP settings (under FFB Tweaks). I have a system in place to mitigate the jitters in the FFB, but it is deactivated if the Real Feel option is enabled.

🟥 **WARNING:** This kart mod is VERY unfinished in many aspects. Some parts of the visual model are missing. The sounds are also very rough and will likely be redone and expanded, if not replaced, by real recordings.

🟩 There is no suspension. Karts just don't have any springs or dampers to soften the ride. However, this doesn't mean there isn't any flex or bounce in the chassis or tires. The tires have some vertical give to them, and the chassis can flex in a few axes, along with the rear axle. This is the main quirk that seperates the driving experience of a kart from that of a car, and its consequences are realistically represented here, as the kart does flex and bounce in-sim, hopefully like a real kart does.