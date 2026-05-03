# 🎮 Magic Grimoire Design Document

> **Version:** 0.1.0-alpha  
> **Genre:** Tactical Hex-Grid Monster-Collecting RPG  
> **Inspirations:** Pokémon × Heroes of Might & Magic × Cardcaptor Sakura  
> **Platform:** PC / Web / Mobile  
> **Engine:** Godot 4.x (2D)

---

## 1. Overview

**Magic Grimoire** is a turn-based tactical RPG where players take on the role of a Summoner — a magic-wielder who travels a fantasy world to collect, train, and battle with magical beings bound to enchanted cards. Each Summoner carries a Grimoire (魔法书) that serves as their card collection.

Battles take place on hex-grid maps with terrain advantages, element type matchups, and customizable unit move-sets. The PVP mode adds strategic depth through a ban/pick phase.

---

## 2. Core Systems

### 2.1 Card System (魔卡)

Each card represents a magical being the Summoner can summon.

| Attribute | Description |
|-----------|-------------|
| Element | Fire / Water / Wind / Earth / Light / Dark |
| Rarity | Common → Legendary |
| Stats | HP, ATK, DEF, SPD, MOV |
| Moves | Up to 4 "active" moves, learnable from a wider pool |
| Evolution | Cards can evolve at certain levels (Pokémon-style) |

### 2.2 Grimoire (魔法书)

The collection UI where Summoners manage all their cards:
- Sort by element, rarity, name
- View detailed stats and move-sets
- Build decks (select which 6 cards to bring to battle)

### 2.3 Summoner System

Summoners have their own progression:
- **Active Skills:** Usable once per turn in battle (heal, terrain change, buff)
- **Passive Abilities:** Auras and permanent effects
- **Equipment:** Staff, Robe, Accessory
- **Level Progression:** Unlocks new skills and abilities

### 2.4 Battle System

#### Map
- Hex grid (radius 8 = ~217 hex map)
- Pointy-top hex orientation
- Axial coordinate system

#### Terrain
| Terrain | Effect |
|---------|--------|
| Grass | Neutral |
| Forest | +20% dodge, boosts Wind |
| Mountain | +10 DEF, boosts Earth (impassable) |
| Swamp | -10% dodge, movement cost x2, boosts Water |
| Water | Impassable, boosts Water |
| Lava | Boosts Fire damage x1.5 |
| Sand | Boosts Earth |
| Ruins | Boosts Dark |
| Magic Circle | Boosts Light |

#### Turn Structure
1. Sort all units by SPD
2. Each unit gets: Move → Action (Attack/Skill) → Wait
3. Summoner can use one skill per turn (shared between all units)

#### Combat Formula
```
base_damage = ((2 * level / 5 + 2) * power * ATK / DEF) / 50 + 2
final_damage = base_damage * element_mult * STAB * random(0.85-1.0)
```

### 2.5 Element Chart

```
Fire > Wind > Earth > Water > Fire
Light <> Dark (mutual super-effective)
```

### 2.6 PVP System

**Pre-Battle Ban/Pick:**
```
Phase 1: Show 6 cards each
Phase 2: Player A bans 1 card from Player B
Phase 3: Player B bans 1 card from Player A
Phase 4: Repeat (2 bans each = 4 cards banned total)
Phase 5: Battle with remaining 4 cards each
```

### 2.7 Capture System (封印仪式)

Instead of Poké Balls, Summoners use **Sealing Rituals**. Different elements require different magic arrays. The success rate depends on:
- Card rarity
- Card remaining HP
- Summoner level
- Sealing tool quality

---

## 3. World Design

### Settings
- **Arcanum Realm:** A fantasy world where magic is the fundamental force
- Ancient wizards sealed magical beings into cards and scattered them across the world
- Summoners travel to collect these cards, uncovering ancient secrets

### Locations
- 🌿 Whispering Woods (Forest encounters)
- ⛰️ Titan's Spine (Mountain encounters)
- 🏜️ Sunscorched Desert (Sand encounters)
- 🏚️ Forgotten Ruins (Dark encounters)
- 🏰 Arcane Academy (Hub / tutorial)
- 🌋 Ember Caldera (Fire/Lava encounters)

---

## 4. Technical Architecture

```
Engine:       Godot 4.3+
Language:     GDScript
Renderer:     GL Compatibility (2D)
Network:      ENET (Godot built-in)
Persistence:  JSON save files
CI/CD:        GitHub Actions
Hosting:      Zeabur (PVP server)
Version:      Git + GitHub
```

### Project Structure
```
magic-grimoire/
├── src/core/        # CardData, MoveData, Element, Database
├── src/battle/      # HexGrid, BattleManager, Battler, AI, Terrain
├── src/systems/     # Grimoire, SaveManager, DeckData
├── src/network/     # PVP System, Matchmaking
├── assets/sprites/  # Unit pixel art
├── assets/tiles/    # Terrain tile sheets
├── assets/cards/    # Card JSON data
├── docs/            # Design docs
└── server/          # Headless Godot PVP server
```

---

## 5. Roadmap

### Phase 0: Prototype (Current) ✅
- [x] Godot project setup
- [x] Hex grid system (axial coords, A* pathfinding)
- [x] Battle manager (turn queue, move execution)
- [x] Card/Move/Element data structures
- [x] AI controller for PVE
- [x] CI/CD workflows
- [x] Sample card database

### Phase 1: Playable Prototype
- [ ] Functional hex grid rendering with terrain
- [ ] Unit movement and attack in GUI
- [ ] Turn visualization
- [ ] 4v4 test battles with AI
- [ ] Basic UI (HP bars, move selection)

### Phase 2: Core Loop
- [ ] Grimoire UI
- [ ] Deck Builder
- [ ] Capture system
- [ ] 15+ cards with unique moves
- [ ] Summoner progression

### Phase 3: World & Campaign
- [ ] Overworld map
- [ ] Story & NPCs
- [ ] Encounters & wild battles
- [ ] Save/Load

### Phase 4: PVP
- [ ] Server infrastructure (Zeabur)
- [ ] Ban/Pick phase
- [ ] Real-time PVP battles
- [ ] Matchmaking & ranking

### Phase 5: Polish
- [ ] Full pixel art assets
- [ ] Sound & music
- [ ] Balance tuning
- [ ] Additional content (more cards, maps, story)

---

## 6. Art Style

- **Pixel Art:** SNES-era 32-color palette, 4px blocks
- **Unit Sprites:** 32x32 to 48x48
- **UI:** Clean pixel font, dark theme with element colored accents
- **Card Illustrations:** Full-color rendered art with pixel-art border frames

---

## 7. Balance Philosophy

- **No one-card-wins:** Team composition beats individual power
- **Element diversity rewarded:** Decks with multi-element coverage perform better
- **PVP ban/pick punishes over-reliance:** If you build around one star card, it WILL get banned
- **Terrain matters:** Position is as important as stats
- **Evolution adds depth:** Early-game weak cards can become late-game powerhouses
