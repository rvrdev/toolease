# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ToolEase is a Flutter-based inventory management kiosk application designed for Android tablets. It manages item borrowing and returning for students with single-admin authentication using device PIN/password.

**Key Characteristics:**

- **Target Platform**: Android tablets (kiosk deployment)
- **User Types**: Students (public access) and Admin (authenticated)
- **Primary Function**: Inventory borrowing/returning workflow with real-time tracking
- **Architecture**: Clean architecture with provider-based state management

## Development Commands

### Basic Flutter Commands

```bash
# Get dependencies
flutter pub get

# Run code generation for Drift database
flutter packages pub run build_runner build

# Clean build artifacts
flutter clean

# Run the app
flutter run

# Build for release
flutter build apk --release

# Analyze code
flutter analyze
```

### Database Code Generation

When making changes to `lib/database/tables.dart`, always run:

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Important**: Database schema changes require careful migration planning. Always test database operations thoroughly.

## Architecture

### State Management

- **Provider Pattern**: Uses `flutter_riverpod` for state management
- **Database Provider**: Centralized database access through `providers/database_provider.dart`
- **Service Layer**: Business logic in `services/` directory

### Database Architecture

- **Drift ORM**: Uses Drift for type-safe database operations
- **Tables**: Defined in `lib/database/tables.dart`
- **Generated Code**: Database implementation in `lib/database/database.g.dart`
- **Service Layer**: Database operations abstracted through `services/database_service.dart`

### Key Data Models

- **Students**: Student registration and management
- **Storages**: Item storage locations (drawers, cabinets)
- **Items**: Inventory items with quantity tracking
- **BorrowRecords**: Borrowing transactions with status tracking
- **BorrowItems**: Individual items within borrow records
- **BorrowItemConditions**: Per-unit condition tracking (good/damaged/lost)
- **Settings**: App configuration and feature toggles

### App Structure

```
lib/
├── core/                   # Design system and themes
├── database/              # Drift database and tables
├── models/                # Data models
├── providers/             # Riverpod state providers
├── screens/               # UI screens
├── services/              # Business logic services
├── shared/widgets/        # Reusable UI components
└── utils/                # Utility functions
```

### Navigation

- Uses named routes with MaterialApp
- Public screens: Home, Register, Borrow, Return
- Protected screens: Admin dashboard and management screens
- Authentication required for admin features using `local_auth`

### Key Features

- **Kiosk Mode**: Restricts system navigation when enabled
- **Borrow ID Generation**: Format `25XXXXX` (year prefix + sequential number)
- **Quantity Condition Tracking**: Individual unit condition tracking for returns
- **Item Restoration**: Lost and damaged items can be restored to stock
  - Lost items: Mark as replaced, restores available quantity
  - Damaged items: Mark as repaired, restores available quantity
- **Real-time Synchronization**: Dashboard updates immediately when items are restored
- **PDF Reports**: Export functionality for records and reports
- **Settings Management**: Feature toggles for screens and kiosk mode

### Design System

- Centralized in `lib/core/` directory
- Exports: colors, typography, spacing, theme
- Reusable widgets in `lib/shared/widgets/`

### Critical Development Patterns

**Database Operations**

- ALWAYS use `DatabaseService` for all database operations
- Use transactions for multi-table operations
- Handle async operations with proper error catching
- Test database operations thoroughly, especially quantity updates
- **Item Restoration Logic**: Both lost and damaged item restoration only updates `availableQuantity`, not `totalQuantity`
- **Provider Invalidation**: Always invalidate relevant providers after database changes for real-time updates

**State Management**

- Use Riverpod providers for shared state
- Implement proper loading and error states
- Refresh data when returning to screens
- Use `AsyncValue` for network/database operations

**UI/UX Standards**

- Follow the established design system in `lib/core/`
- Use `AppCard`, `ActionCard` for consistent styling
- Implement proper error handling with user feedback
- Ensure accessibility compliance

**Navigation**

- Use named routes for public screens
- Direct navigation for admin/authenticated screens
- Implement proper back button behavior
- Handle navigation in kiosk mode appropriately

## Development Guidelines

### Code Quality Standards

1. **Error Handling**: Always implement try-catch blocks for async operations
2. **Type Safety**: Use proper model classes and avoid dynamic types
3. **Performance**: Implement proper loading states and avoid blocking UI
4. **Testing**: Test critical paths, especially borrow/return workflows
5. **Documentation**: Document complex business logic and database operations

### Security Considerations

- Never log sensitive information (student IDs, personal data)
- Validate all inputs before database operations
- Use proper authentication for admin features
- Implement proper session management

### Database Schema Rules

- Never modify existing tables without migration strategy
- Always backup database before schema changes
- Test quantity tracking logic thoroughly
- Maintain referential integrity

### Kiosk Mode Considerations

- Test all features work with restricted navigation
- Implement proper gesture handling for admin access
- Ensure app remains functional if system buttons are disabled
- Handle screen rotation and orientation changes

## Troubleshooting Common Issues

**Database Generation Errors:**

```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Provider State Issues:**

- Ensure providers are properly initialized
- Check for circular dependencies
- Verify AsyncValue handling

**Kiosk Mode Problems:**

- Check device permissions
- Verify kiosk service implementation
- Test gesture recognition

## Item Restoration Feature

The application supports restoring lost and damaged items back to available stock through the Manage Records screen.

### Restoration Types

**Lost Items → Replacement**

- Items marked as "lost" can be restored by marking them as "replaced"
- Updates only `availableQuantity` (not `totalQuantity`)
- Each selected condition restores exactly 1 unit to available stock

**Damaged Items → Repair**

- Items marked as "damaged" can be restored by marking them as "repaired"
- Updates only `availableQuantity` (not `totalQuantity`)
- Each selected condition restores exactly 1 unit to available stock

### Implementation Details

**Database Methods:**

- `restoreLostItemsToStock(List<int> conditionIds)` - Restores lost items
- `restoreDamagedItemsToStock(List<int> conditionIds)` - Restores damaged items

**UI Features:**

- Individual item selection with checkboxes
- Batch restoration operations
- Confirmation dialogs
- Real-time dashboard updates via provider invalidation

**Key Logic:**

- Each `QuantityCondition` represents exactly 1 unit
- Restoration changes condition from `lost`/`damaged` to `good`
- Only `availableQuantity` is increased, `totalQuantity` remains unchanged
- Providers are invalidated for immediate UI updates across the app
