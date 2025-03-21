# Helpful Godot Scripts

This document outlines several essential script patterns used by an experienced Godot developer across multiple game projects.

## Global Script

A script loaded as an Autoload that can be accessed from anywhere in the game.

**Setup:**
- Configure via Project Settings → Autoload tab
- Access using the name configured in Autoload (e.g., `Global.variable_name`)

**Common Uses:**
- Store singleton-like managers (e.g., card manager)
- Maintain a single Random Number Generator (RNG) instance
- Store reference to main scene with `Global.main = self`

## Signal Bus

An Autoload script that provides globally available signals for communication between disconnected parts of your game.

**Purpose:**
- Define signals that can be connected to from anywhere
- Example: spawning state changes that trigger connected methods across the game

**Important Notes:**
- Best for when multiple systems need to react to events
- Not suitable when specific execution order is required
- Godot doesn't guarantee signal execution order

## Utility Script (Util)

An Autoload script containing constants, enums, and utility methods.

**Key Features:**
- Houses enums ("the bones of the project")
- Maintains consistency across the project
- Ensures same references (colors, types, etc.) throughout the game

**Example Use:**
- Resource type enums that ensure consistent reference
- Helper functions accessed from anywhere in the project

## Reference Scene

A scene with attached script containing export variables, loaded as an Autoload.

**Benefits:**
- Visually set colors instead of using hex codes
- Access resources by type using enums
- Prevents broken references when moving files
- Keeps resources (textures, colors) consistent throughout the project

## Scene Changer

A scene transition manager loaded as an Autoload.

**Features:**
- Uses AnimationPlayer for smooth transitions
- Simple fade in/out between scenes
- Uses enum-based scene selection for easy reference

## Audio Manager

Handles audio playback with limits to prevent audio clipping.

**Key Feature:**
- Limits number of simultaneous sound effects
- Creates a queue system for audio effects
- Tracks active sounds and manages new requests

**Use Case:**
- Multiple collectible pickups playing sound simultaneously
- Prevents audio overload by limiting concurrent sounds

## Hexagon Utility Class

Tools for working with hexagonal grids.

**Based on:**
- Red Blob Games' hexagon grid blog
- Provides conversion and calculation methods for hex coordinates
- Requires cell size parameter based on texture size

## Best Practices

1. **Autoload Order:** The order matters for scripts that depend on each other.
2. **Signals:** Good for loose coupling, but don't guarantee execution order.
3. **Enums:** Use them for consistency across your project.
4. **References:** Use reference scenes to visually configure constants.
5. **Iteration:** Game development is challenging - start moving in any direction and learn as you go.