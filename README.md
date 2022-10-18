# JAIDA

A simple and short adventure game made in Jai. 

## Controls
WASD  : Move
E     : Interact
SPACE : Attack

## Build
Just run `jai src/build.jai`.
You can comment out the optimization level line for a debug build.
For dev tools change `Compiler.add_build_string("DEVELOPER :: false;", w);` to `Compiler.add_build_string("DEVELOPER :: true;", w);`

## Assets
- All graphical (sprites & fonts) are from [pixel-boy](https://pixel-boy.itch.io/ninja-adventure-asset-pack) (cc0)
- Music is by me with the OP-Z
- SFX is made with [sfxr](https://www.drpetter.se/project_sfxr.html)

## Notes
- Most of the game uses the Modules given with the compiler. The only thing that works without is the audio that just uses SDL.
- Compile-time execution isn't too crazy. It is mostly used for a basic resources system. At compile time I look into the res/audio and res/actor folder and populate the sounds and actors struct respectively. This allows me to have access to all files in a folder without adding each file one by one. 
- The `ecs.jai` and `components.jai` file aren't compiled. I experimented a bit with an ecs system allowing you to create components only by tagging structs with @Component. Things got crazy really fast so I stopped and went for a simpler approach.
- There is a basic map editor. With the `DEVELOPER` global to true, press F1 to switch to editor mode. Tab opens the map sprite sheet, click on a tile to select it. Then Left Click on the map to add that tile, Right Click to delete, Middle Click to Eyedrop. Switch layer with F2/F3. The last layer is the collision layer. Everything not empty will block. `keymaps.jai` has a full list.
- The rest of the code should be fairly straight forward

## Screenshots
![1](https://github.com/Sl3dge78/jaida/blob/main/screenshots/1.png?raw=true)  
![2](https://github.com/Sl3dge78/jaida/blob/main/screenshots/2.png?raw=true)  