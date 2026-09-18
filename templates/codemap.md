# 🗺️ Code Map & Interface Registry

> **Rule for All Agents:** Before creating a new file, function, utility, or wrapper class, you MUST scan this map. If a module exists that covers the use case, you must extend or import it. Do NOT reinvent existing abstractions or add redundant wrappers.
>
> **The Callable Contract Standard:** For each component, record the callable contract so an agent can call, import, or test it without reading the source. Document the pattern fitting your system architecture:
> - **General Programming (Libraries / APIs / Services):** Record exported functions/classes, argument/return types, thrown errors, and state/database/network side effects.
> - **System & CLI Architecture (CLIs / Scripts / Daemons):** Record invocation forms (args, stdin), outputs (stdout, stderr), exit codes, environment variables read, and files/buffers touched.

---

## 🏗️ 1. Core Modules & Owners

### 🔐 [Module 1: General Code Example] (`src/.../`)
* **Purpose:** Single source of truth for ...
* **Callable Contract (Code / API):**
  * **Entrypoint:** `Service.process(req: RequestPayload) -> Result<ResponseData, ServiceError>`
  * **Inputs & Context:** Validated payload schema, required injected dependencies.
  * **Return & Errors:** Resolves `ResponseData` on success; throws `InvalidStateError` or returns `Err(ServiceError)`.
  * **Side Effects:** Writes to `db_table`, mutates cache key `session:<id>`.
* **Anti-Wrapper Warning:** What NOT to duplicate or wrap.

### ⚙️ [Module 2: CLI / System Example] (`bin/...` or `scripts/...`)
* **Purpose:** Single source of truth for ...
* **Callable Contract (CLI / Script):**
  * **Invocation:** `tool-cmd [flags] <target>` (stdin: optional JSON/stream payload)
  * **Outputs:** stdout: formatted result; stderr: structured diagnostics
  * **Exit Codes:** `0` = success, `1` = runtime failure, `2` = validation / permission denial
  * **Environment Variables:** `TOOL_CONFIG_PATH` (defaults to `~/.config/tool`)
  * **Files Touched:** Reads `path/to/input`, writes `path/to/output`
* **Anti-Wrapper Warning:** Never write ad-hoc shell wrappers around this command.

---

## 🛑 2. Shared Utilities (Look Here First)

### 🛠️ [Utility Name] (`src/utils/...`)
* **Available Functions / Exports:**
  * `format_data(val: string) -> string` -> Formats input per canonical spec.
* **Anti-Wrapper Warning:** Never write inline duplicates of this utility.

---

## 🚦 3. Interface Contracts & Architectural Invariants
* **Error Handling:** Standard error throwing, exit code conventions, or Result monad.
* **State Management:** How global / local state or configuration is passed.
* **Boundary Invariants:** Strict layer boundaries (e.g. controllers never call database directly).

