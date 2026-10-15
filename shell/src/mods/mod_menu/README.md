# Mod Menu

Press **F1** in-game. Other mods register rows with:

```
host.emit("mod_menu.register", {
  id: "my_tool",
  label: "My Tool",
  section: "Modes",           // sort bucket / header
  notes: "Billboard help text shown when hovered",
  guide: false,               // true = non-selectable hint row
  visible: optionalFn,        // Function():Boolean
  onSelect: myFn,
  nowPlaying: optionalFn,     // Function():String — upper-right song
  onNowPlaying: optionalFn    // open music player when song clicked
});
host.emit("mod_menu.unregister", { id: "my_tool" });
```

`host.emit("mod_menu.open")` opens the menu. The menu emits `mod_menu.ready` after boot; register rows then if you load late.

Esc / F1 / B closes. Input is blocked while open. A secondary open key (keyboard or controller button) can be bound from the menu; it is saved as `mod_menu.hotkey`.

The **Mods** section lists installed packs. Select one to turn it on or off. Essential packs stay on. Toggling reloads mods and reopens this menu.
