# 🗺️ Code Map & Interface Registry

> **Rule for All Agents:** Before creating a new file, function, utility, or wrapper class, you MUST scan this map. If a module exists that covers the use case, you must extend or import it. Do NOT reinvent existing abstractions or add redundant wrappers.

---

## 🏗️ 1. Core Modules & Owners

### 🔐 [Module 1: Name & Path] (`src/.../`)
* **Purpose:** Single source of truth for ...
* **Key Interfaces / Functions:**
  * `function_name(args)` -> What it returns/does.
* **Anti-Wrapper Warning:** What NOT to do or duplicate.

---

## 🛑 2. Shared Utilities (Look Here First)

### 🛠️ [Utility Name] (`src/utils/...`)
* **Available Functions:**
  * `helper_function()` -> What it does.
* **Anti-Wrapper Warning:** Never write inline duplicates of this utility.

---

## 🚦 3. Interface Contracts & Architectural Invariants
* **Error Handling:** Standard error throwing / logging mechanism.
* **State Management:** How global / local state is passed.
