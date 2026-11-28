# Hybrid 3D / CAD & FlexSim Automation Patterns

1. **Zoom Before Picking `<15px` 3D Targets**: Small control points or overlapping paths (e.g., `Path1` shadowing `ControlPoint1`) fail at overview zoom. Move the cursor near the target and call `desktop_mouse_wheel(dy=8..10)`, capture `screen=0`, and ground with `scripts/som_grid.ps1 -Scale 2 -Step 20`.
2. **Semantic Property Pickers > 3D Drag Connections**: On FlexSim/CAD canvases, dragging `A`-links across 3D objects can throw `Exception Caught in defaultdragconnection function`. Prefer property-panel `吸管` (`Eyedropper`) buttons (`Location`, `输入端口`, `输出端口`) or numeric geometry (`地点 X/Y`, `半径`, `起始角度`, `扫射角度` for `弯曲路径`) over fragile `路径衔接` mouse gestures.
3. **Verify Sticky Toolbar Mode Icons**: FlexSim's `A/S/Q` port-connection button retains whichever icon (`A` or `S`) was last picked from its `▼` dropdown. Always verify the active icon on the latest toolbar crop before clicking, or open `▼` explicitly to avoid silent Center-Port (`S`) vs Input-Port (`A`) mismatches.
4. **Collapse Property Sections Bottom-Up**: Collapsible right-panel groups (`统计`, `模板`, `外观`) shift all lower controls vertically. Collapse unneeded sections **bottom-up** so upper target Y-coordinates stay stable, and re-read bounds via `desktop_snapshot(root="@panel_ref", include_bounds=true)` after any toggle.
5. **Detect Hidden Modals & Floating `As Dialog` Popups**: Modal dialogs (`尺寸表格`, `代码编辑器`, `另存为`, `功能不可用`) and accidental `A`-mode `As Dialog` popups are invisible in `desktop_screenshot(window_id=main)`. Whenever clicks or keys stop responding, run `desktop_list_windows()` + `desktop_screenshot(screen=0)` immediately.
6. **Quota Limits & Checkpoints**: In Express editions (e.g., 30 3D objects limit, disabled `模型树`/`脚本`/`事件列表`), press `ctrl+z` immediately after any misdrop rather than stacking retries, and press `ctrl+s` after completing each major phase (layout, parameters, connections).


## 7. FlexSim 2022 (`.fsm`) Coursework & Simulation Verification Rules

1. **In-Place `.fsm` Target Discipline**: Confirm the target `.fsm` file path first. For an explicitly named coursework file, edit and save that `.fsm` file in place (`ctrl+s`) unless the user asks for a derivative copy.
2. **Direct Model Expressions Over Blind Clicking**: Where FlexSim property fields accept FlexScript/model expressions, prefer exact references such as `Model.find("操作员1")` and `Model.find("任务分配器2")`. For cache/center-port routing expressions, use `current.centerObjects[2]`; for queue/cache part counts, check `current.subnodes.length`.
3. **Flow (`A`) vs. Center-Port (`S`) Connections**:
   - **Flow connections (`A` mode)**: Hold `A` (or activate the toolbar `A`连接对象 mode), click the upstream object (`发生器` / `暂存区` / `处理器`), then click the downstream object (`暂存区` / `处理器` / `吸收器`), and release or press `Esc`.
   - **Task-executer / Center-port connections (`S` mode)**: Use `S` (居中端口连接) or property-panel `吸管` (`Eyedropper`) pickers to bind `任务分配器` (`Dispatcher`) or `操作员` (`Operator`) to fixed resources. Verify visually that port triangles/lines appear between the intended objects.
4. **Genuine Isolation in Worker / Task-Allocator Comparisons**:
   - Changing a reference field alone does **not** disable an extra worker or task allocator if center-port (`S`) or dispatcher connections remain active.
   - To isolate a single-worker comparison without losing object configuration, **disconnect** (`Q` mode / unbind ports) or explicitly disable the extra resource (e.g., disconnect `操作员1` or the extra `任务分配器`) rather than leaving it wired into the dispatcher queue.
   - Preserve or record each valid comparison configuration before overwriting it for the next experiment.
5. **Wall-Clock Wait (`ms`) vs. Simulation Clock (`seconds`)**:
   - Never conflate wall-clock `desktop_wait` duration (e.g., waiting `10000 ms` in real time) with FlexSim simulation time (`Run Time` in seconds on the model clock).
   - Read the actual simulation clock and object statistics (`输入` / `输出` throughput, `当前内容` queue content, `停留时间` stay time, and state percentages) after `Reset` -> `Run` -> `Stop`.
6. **Priority & Dispatch Verification**: A normal transport run does not prove processing or dispatch priority. Inspect the `任务分配器` / processor priority fields or dispatch rules directly, and validate with observable task ordering or downstream per-object statistics.
7. **Mandatory `.fsm` Disk Write Verification**: After pressing `ctrl+s`, verify in PowerShell that the `.fsm` file on disk updated its `Length` and `LastWriteTime`:
   ```powershell
   Get-Item -LiteralPath "<path-to-file.fsm>" | Select-Object FullName, Length, LastWriteTime | Format-List
   ```
