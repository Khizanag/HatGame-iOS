# DesignBook

A Swift Package containing the design system for the Hat Game iOS application.

## Overview

DesignBook provides a centralized design system with consistent styling, spacing, colors, and typography for the Hat Game app.

## Components

- **Typography**: Fonts and text styles
- **Colors**: App color palette (Background, Text, Status, Button)
- **Spacing**: Consistent spacing values
- **Size**: Standardized sizes for UI elements
- **Opacity**: Predefined opacity levels
- **Shadow**: Shadow definitions for depth and elevation

## Usage

Import the package in your Swift files:

```swift
import DesignBook
```

Then use the design tokens:

```swift
Text("Hello")
    .font(DesignBook.Font.headline)
    .foregroundColor(DesignBook.Color.Text.primary)
    .padding(DesignBook.Spacing.md)
```

## Requirements

- iOS 17.0+
- Swift 5.9+

## Integration

This is a local Swift Package. Add it to your Xcode project:

1. In Xcode, go to File → Add Package Dependencies
2. Click "Add Local..."
3. Navigate to the DesignBook folder
4. Click "Add Package"
