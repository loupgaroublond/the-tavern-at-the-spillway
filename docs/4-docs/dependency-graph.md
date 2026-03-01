# Module Dependency Graph

Generated 2026-03-01. Edges mean "depends on" (arrow points to the dependency).

## Full Graph

```mermaid
graph TD
    Tavern["Tavern (app)"]
    TavernCore
    TavernBoardTile
    ChatTile
    ResourcePanelTile
    ServitorListTile
    PermissionSettingsTile
    ApprovalTile
    CoreProviders
    CoreUI
    CoreModels
    ClodKit["ClodKit (external)"]

    Tavern --> TavernCore
    Tavern --> TavernBoardTile
    Tavern --> CoreProviders
    Tavern --> CoreUI

    TavernCore --> CoreModels
    TavernCore --> CoreProviders
    TavernCore --> ClodKit

    TavernBoardTile --> CoreModels
    TavernBoardTile --> CoreProviders
    TavernBoardTile --> ApprovalTile
    TavernBoardTile --> PermissionSettingsTile
    TavernBoardTile --> ServitorListTile
    TavernBoardTile --> ResourcePanelTile
    TavernBoardTile --> ChatTile

    ChatTile --> CoreModels
    ChatTile --> CoreProviders
    ChatTile --> CoreUI

    ResourcePanelTile --> CoreModels
    ResourcePanelTile --> CoreProviders
    ResourcePanelTile --> CoreUI

    ServitorListTile --> CoreModels
    ServitorListTile --> CoreProviders

    PermissionSettingsTile --> CoreModels
    PermissionSettingsTile --> CoreProviders

    ApprovalTile --> CoreModels

    CoreProviders --> CoreModels
    CoreUI --> CoreModels
```

## Declared but Unused Dependencies

These edges exist in Package.swift but are never actually imported in code:

| Source | Declared Dep | Status |
|--------|-------------|--------|
| ApprovalTile | CoreUI | Never imported |
| ServitorListTile | CoreUI | Never imported |
| PermissionSettingsTile | CoreUI | Never imported |
| TavernBoardTile | CoreUI | Never imported |
| Tavern (app) | CoreModels | Never imported |

## CoreUI Actual Consumers

Only 2 tile modules actually import CoreUI:

| Consumer | Types Used |
|----------|-----------|
| ChatTile | `MessageRowView`, `MultiLineTextInput` |
| ResourcePanelTile | `LineNumberedText` |

## Test Targets

```mermaid
graph TD
    TavernCoreTests --> TavernCore
    TavernCoreTests --> CoreModels

    TavernTests --> Tavern["Tavern (app)"]
    TavernTests --> TavernCore
    TavernTests --> CoreModels
    TavernTests --> CoreUI
    TavernTests --> ViewInspector["ViewInspector (external)"]

    TavernIntegrationTests --> TavernCore
    TavernIntegrationTests --> CoreModels

    TavernStressTests --> TavernCore
    TavernStressTests --> CoreModels
```
