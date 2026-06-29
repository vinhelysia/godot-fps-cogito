# 🎯 Godot FPS Extraction — Project Index

> Map of Content (MOC) cho project FPS extraction-shooter build trên **Cogito** (Godot 4.6).
> Đây là điểm vào — mọi note khác link từ đây.

## Quyết định cốt lõi (locked)
- **Genre:** Extraction shooter (Tarkov-like).
- **Scope:** Single-player trước, multiplayer tính sau (chấp nhận retrofit cost).
- Lý do & chi tiết → [[Roadmap]]

## Notes chính
- [[Roadmap]] — 5 phase từ vertical slice tới go-wide.
- [[Architecture]] — weapon chain, inventory grid, NPC/AI system, Cogito boundary, bug nền.
- [[Codebase Map]] — index cơ học **AUTO-GENERATED** (autoloads, input actions, mọi `Scripts/*.gd` class_name/funcs, bảng class cogito, scene roots).
- [[Dev Log]] — nhật ký thay đổi (cleanup, fixes, rotation, branches, git state).
- [[Scav AI Prompt]] — prompt chi tiết build enemy đầu tiên (đang giao Sonnet).

## 🤖 Cách AI dùng vault này (3 lớp — "hiểu codebase không scan lại")
1. **`CLAUDE.md` + `AGENTS.md`** (auto-load mỗi session) trỏ tới vault này → AI biết đọc đây trước khi scan repo.
2. **Vault** (note tay): kiến thức "why" sâu — [[Architecture]], [[Roadmap]], [[Dev Log]].
3. **[[Codebase Map]]** (sinh bằng script): sự thật cơ học, **regenerate** khi code đổi:
   `bash godot-fps-cogito-master/tools/gen_codebase_map.sh`
- ⚠️ Map là *snapshot* → AI luôn verify path/func/line ở file thật trước khi sửa code.
- 📌 Khi có thay đổi: cập nhật [[Dev Log]] + chạy lại generator.

## Trạng thái nhanh
- ✅ Systems mạnh: weapon (ballistics, chambering, ADS, scope), inventory grid + rotation, full Cogito immersive-sim.
- ❌ Thiếu để thành "game": **enemy AI**, core loop (raid → loot → extract/die), level thật.
- 🔜 Việc đang chạy: **Scav AI** (xem [[Scav AI Prompt]]).

## Repo
- GitHub: `vinhelysia/godot-fps-cogito` — chỉ còn branch `master` (đã dọn).
- Local project root: `C:/Stuff/godot-fps-cogito-master/godot-fps-cogito-master/`
- Chi tiết git state → [[Dev Log]]
