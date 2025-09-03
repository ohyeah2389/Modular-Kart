## Known Issues

- AI-controlled karts explode violently upon spawn

I don't know why this issue occurs, but it could be due to their steering control interfering with the COSMIC suspension configuration.

- Bodywork stickers flicker when the camera is far away

This is due to the bodywork models not being finalized yet. I'll finalize the bodyworks when I've finished modeling most of the bodyworks that I want to add, which will remove the underneath plastic layer, removing the flickering. UV maps will also be added at that time, allowing for custom paint schemes more complex than solid colors.

- Bodywork selection doesn't sync online

This is a limitation of the setup system: setup values aren't transmitted across clients. This will likely be fixed after the bodywork is finalized; I'll be moving the bodywork selection outside the game: the setup options will be removed and bodywork selection will be handled skinwise via skin-specific `ext_config.ini` selection/loading of bodywork meshes. This does mean that you won't be able to change bodywork/visual options in-game, but as long as every client and the server has the skin that a client is using, their specific bodywork should show correctly.

- Driver animations (hand raise, tuck) don't sync online

This is a limitation of the CSP Extra controls system: the Extra A, B, C, etc. states aren't transmitted between clients. I'm brainstorming a fix for this but I haven't come up with anything concrete yet; if you have any good ideas, please let me know!

- Poor performance with multiple karts, especially online

This is due to the very large number of draw calls the kart currently generates. Many objects which are usually grouped for optimization reasons (all wires, all non-moving chassis-attached bits, all parts belonging to one sidepod, etc.) haven't been joined yet. This is a late-stage optimization task that can't be performed until I've finalized each object group, which will happen much later on in development.

- Hands detatch from steering wheel, or they don't smoothly track it

This is a result of the inverse kinematics system I implemented to allow the driver's hands to track the wheel even when the driver's body leans, rotates, and tucks. It's an iterative solver, and I can't let it run for too long per-frame as it will drag down performance too far. The less the steering wheel moves per frame, the better it'll track the wheel, which means that higher framerates are better. 40FPS and less will result in poor tracking and a bad-looking steering animation. This is my first time implementing an inverse kinematics system and I'm sure I did it pretty poorly; if you have any notes or suggestions from examining my code, feel free to share them with me-- or better yet, make a pull request!

- Driver body jumps when pausing/unpausing game or replay, or when camera is far away

This is either a limitation with how drivers can be animated using CSP Lua or a deficiency of how I've animated the driver using CSP Lua. Script execution is paused when the game is paused or the camera passes the script distance threshold, and if the script isn't allowed to execute, the 