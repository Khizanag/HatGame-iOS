# Navigation

A Swift Package containing a flexible, type-safe navigation system for iOS applications.

## Overview

Navigation provides a struct-based navigation system that uses static extensions for defining app-specific pages. This approach combines type safety with flexibility, allowing you to define pages with associated data while maintaining a clean API.

## Components

- **Page**: A struct representing a navigable page with an ID and view builder
- **Navigator**: Navigation coordinator that manages navigation state
- **NavigationView**: Navigation wrapper that handles navigation stack and modal presentations

## Usage

Import the package in your Swift files:

```swift
import Navigation
```

Define your app's pages using static extensions:

```swift
extension Page {
    // Simple pages
    static let home = Page(id: "home") {
        HomeView()
    }

    static let settings = Page(id: "settings") {
        SettingsView()
    }

    // Pages with associated data
    static func userProfile(userId: String) -> Page {
        Page(id: "userProfile-\(userId)") {
            UserProfileView(userId: userId)
        }
    }

    static func detail(item: Item) -> Page {
        Page(id: "detail-\(item.id)") {
            DetailView(item: item)
        }
    }
}
```

Use NavigationView in your app:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                Page.home.view()
            }
        }
    }
}
```

Navigate using Navigator:

```swift
@Environment(Navigator.self) var navigator

// Push a page
navigator.push(.settings)

// Push with associated data
navigator.push(.userProfile(userId: "123"))

// Present modally
navigator.present(.detail(item: selectedItem))

// Dismiss
navigator.dismiss()

// Pop to root
navigator.popToRoot()

// Replace current page
navigator.replace(with: .home)
```

## Architecture Benefits

- **Type-safe**: All pages are statically defined
- **Flexible**: Support for pages with associated data (like enum cases)
- **Clean API**: Simple, SwiftUI-idiomatic navigation
- **No circular dependencies**: Package doesn't depend on your app's views
- **Reusable**: Can be used across multiple projects

## Requirements

- iOS 17.0+
- Swift 5.9+

## Integration

This is a local Swift Package. Add it to your Xcode project:

1. In Xcode, go to File → Add Package Dependencies
2. Click "Add Local..."
3. Navigate to the Navigation folder
4. Click "Add Package"
