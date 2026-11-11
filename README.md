# Steel Concordat

A mech mercenary guild manager with real-time autobattler combat, in a single HTML file.

Run a guild from the scrapyards of the Salvage League to the Apex Circuit: draft pilots, outfit their mechs, program each pilot's combat AI with command priorities, and send squads on contracts against raider clans, rogue Ghost Frames and the alien Hollow.

## Play

Open `index.html` in a modern browser. There is nothing to install or build. Saves are kept in the browser's local storage.

Landscape orientation is recommended on phones.

## Features

- **Guild management**: two squads plus reserves, weekly training (rest, drill a stat, sim tactics, mentoring), facilities, market, free agents, contracts and a league season with promotion and relegation series.
- **Pilots**: seven color-coded stats and overall ratings, perks, class specializations, morale and fatigue, and procedurally drawn portraits that wear the guild's colors once recruited.
- **Mechs**: four weight classes with distinct speed, acceleration, turning and booster cooldowns, plus procedurally assembled humanoid frames (head, shoulders, chest, backpack, legs, trim).
- **Weapons**: 22 types, including autocannon, gatling, pulse laser, scattergun, gauss rifle, railgun, beam lance, ion cannon, plasma cannon, arc caster, flamer, rockets, guided missiles, seeker swarms, mortar, chainblade, thunder hammer, plasma katana and pile bunker.
- **Combat AI**:
  - Missiles with different homing strengths, point-defense guns and booster dash-dodging.
  - Cover-seeking, and routing around walls and buildings.
  - Melee footwork: circling, flanking, striking and peeling away.
  - Knockback and stagger.
- **Expeditions**: procedural sector maps with scouting and fog of war across four biomes: wasteland, ruined city, ice moon and alien hive.
- **Guild identity**: a three-color banner, 28 emblems, and mechs and pilot uniforms tinted in the guild's colors.

## Tech

One self-contained `index.html`: vanilla JavaScript, Canvas 2D for battles and inline SVG for portraits, emblems and maps. It has no dependencies apart from optional Google Fonts.
