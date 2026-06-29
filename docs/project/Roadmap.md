# Roadmap — Extraction Shooter (SP first)

> Quay về [[🎯 Project Index]]

## Quyết định
- **Core loop:** Extraction (Tarkov-like) — raid để loot rồi extract, chết thì mất đồ mang theo.
- **Multiplayer:** KHÔNG trong scope ngay. SP trước cho chắc. Giữ gameplay logic không phụ thuộc cứng local-only ở chỗ rẻ (vd damage/health qua 1 điểm tập trung) để đỡ đau khi retrofit.

## Nguyên tắc: vertical slice trước, go-wide sau
Đừng chia tuần tự "systems hết → rồi level". Build slice mỏng (loop + 1 địch + 1 graybox) để validate vui, **rồi mới** đi rộng.

## Loop vs hiện trạng
| Mảnh loop | Trạng thái |
|---|---|
| Firefight fidelity (ballistics, chambering, ADS, scope) | ✅ Mạnh |
| Grid inventory + rotation, ammo-as-item, mag/chamber | ✅ Xong |
| Loot container + loot generator (đã fix unique/quest bug) | ✅ Có |
| Save/load, health attribute, pickup/drop, footstep | ✅ Có |
| **Enemy AI (scav)** | ❌ Gap #1 → [[Scav AI Prompt]] |
| Extraction zone | ❌ |
| Raid lifecycle (insert → raid → extract/die → result) | ❌ |
| Death = mất đồ mang theo | ❌ |
| Stash / meta layer (đồ giữ giữa raid) | ❌ |

## 5 Phase
1. **Scav AI** (ưu tiên cao nhất) — patrol → detect (LOS) → chase → **shoot** → chết + drop loot. Unblock việc tune combat. → [[Scav AI Prompt]]
2. **Vòng raid** — extract zone (Area3D + đứng N giây → giữ loot); death-drop; raid flow.
3. **Meta layer** — tách *raid inventory* (mất khi chết) khỏi *persistent stash*; màn gear-up tối giản.
4. **Graybox 1 map nhỏ** + đặt loot spawn / container + navmesh.
5. **Playtest loop → tune → go wide** (AI sâu hơn, level design thật, nhiều map, trader/quest/hideout).

## Lưu ý
- Fix loot_generator (xem [[Dev Log]]) rất quan trọng — loot table điều khiển nền kinh tế extraction.
