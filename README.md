# WhackAMole (打地鼠)

WhackAMole is a World of Warcraft (3.3.5a) addon designed to help players with their rotation by visualizing the next best spell to cast, like a game of whack-a-mole. It is specifically optimized for the Titan-Forged private server environment but follows standard WotLK logic.

## Features

- **Visual Rotation Assistance**: Shows the next ability to press directly on your screen.
- **Dynamic Layout**: Automatically arranges ability icons based on priority and type.
- **Profile Support**: Comes with built-in profiles for supported classes (currently focused on Fire Mage).
- **Titan-Forged Optimizations**: Includes logic adjustments for custom server mechanics like T10 set bonuses.
- **Easy Configuration**: Drag-and-drop to remove unwanted suggestions, right-click to configure.

## Installation

1.  Download the repository.
2.  Copy the `WhackAMole` folder to your WoW AddOns directory:
    `Interface\AddOns\WhackAMole`
3.  (Optional) If you are a developer, copy `.env.example` to `.env` and set your WoW path, then use `publish.ps1` to deploy.

## Usage

-   **/mole** or **/whackamole**: Open the configuration menu.
-   **Right-click** the addon frame header to access quick options (Lock/Unlock, Clear).
-   **Drag** an icon off the bar to remove it from the suggestion list (when unlocked).
-   **Drag** a spell from your spellbook onto a slot to manually assign it (drag support is limited in combat).

## License

MIT
