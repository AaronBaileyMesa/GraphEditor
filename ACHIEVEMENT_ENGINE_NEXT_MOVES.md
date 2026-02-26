# Achievement Engine - Suggested Next Moves

**Date**: 2026-02-25
**Context**: Phase 1 foundation complete, ready for UI layer

## Session Recap

This session successfully completed the Achievement Engine foundation:

### ✅ What We Built
1. **AttemptNode** - Records each completed event with metrics
2. **MilestoneNode** - Unlockable achievements with tier progression
3. **Taco Night milestone tree** - 5 milestones across 4 tiers
4. **Unlock mechanics** - Previous milestones, attempt counts, metric thresholds
5. **Graph integration** - Initialization, attempt recording, progress queries
6. **Performance optimization** - Reduced console logging from 6000+ to ~100 lines

### 🎯 Key Validations
- Graph engine naturally handles achievement progression ✅
- NodeTypeDescriptor pattern works for achievement nodes ✅
- Multi-graph support correctly isolates personal vs meal graphs ✅
- Stable UUIDs maintain milestone identity across sessions ✅
- Architecture supports adding new domains without fundamental changes ✅

## Recommended Next Moves

### Option 1: Create Achievement Dashboard (Highest Value)
**Why**: Makes achievements visible and rewarding - core value proposition
**Effort**: Medium (2-3 hours)
**Impact**: High - users can actually see and interact with progression

**Tasks**:
1. Create `AchievementDashboardView.swift` in GraphEditorWatch/Views/
2. Display milestone tree with tier-based layout
3. Show locked/unlocked/completed states with appropriate icons
4. Display recent attempts with metrics
5. Add navigation from main menu
6. Include celebration UI for unlocks

**Design Considerations**:
- Watch screen is small - use list view with expand/collapse
- Show milestone tree as hierarchical list (tier groupings)
- Tap milestone to see requirements and progress
- Separate section for recent attempts
- Use colors consistently (green/blue/purple/yellow for tiers)

**Success Metric**: User can see all 5 milestones, understand what's required, and track progress

---

### Option 2: Position Attempt Nodes Intelligently (Quality of Life)
**Why**: Prevents stacking at (0,0), makes graph view usable
**Effort**: Low (30-60 minutes)
**Impact**: Medium - improves graph visualization

**Tasks**:
1. Modify `recordAttempt()` in GraphModel+Achievements.swift
2. Position attempt nodes near their linked event
3. Add slight offset to avoid exact overlap
4. Consider timeline layout (vertical by date)

**Implementation**:
```swift
// In recordAttempt(), after creating attempt:
if let linkedEvent = nodes.first(where: { $0.id == attempt.linkedEventID }) {
    let offset = CGPoint(x: 50, y: 0) // Offset from event
    let positioned = AttemptNode(
        // ... existing params ...
        position: linkedEvent.position + offset,
        // ... remaining params ...
    )
    nodes.append(AnyNode(positioned))
}
```

**Success Metric**: Attempt nodes appear next to their meal events in graph view

---

### Option 3: Hook Up Menu Actions (Completeness)
**Why**: Finish the interaction loop for milestones and attempts
**Effort**: Low (30 minutes)
**Impact**: Medium - enables completion tracking

**Tasks**:
1. Implement "Mark as Completed" in MilestoneNodeDescriptor
   - Update milestone status to .completed
   - Save graph
   - Show confirmation/celebration
2. Implement "View Linked Event" in AttemptNodeDescriptor
   - Navigate to linked MealNode
   - Focus graph on that node
   - Or open meal detail view

**Success Metric**: User can mark milestones complete and navigate to linked events

---

### Option 4: Add Celebration UI (Delight Factor)
**Why**: Makes unlocks feel rewarding
**Effort**: Medium (1-2 hours)
**Impact**: High - core engagement mechanic

**Tasks**:
1. Create `MilestoneUnlockView.swift` celebration sheet
2. Show milestone details (name, tier, reward text)
3. Add animation (confetti, haptics)
4. Display in `recordTacoNightCompletion()`
5. Queue multiple unlocks if more than one

**Design**:
- Full-screen sheet with milestone icon
- Animate tier badge appearing
- Show reward text
- Haptic feedback (success)
- "Continue" button to dismiss

**Success Metric**: Unlocking a milestone feels exciting and rewarding

---

### Option 5: Test End-to-End Flow (Validation)
**Why**: Verify the whole system works before adding complexity
**Effort**: Low (1 hour)
**Impact**: High - catches issues early

**Tasks**:
1. Create test script for milestone progression
2. Host events with specific metrics:
   - 1 event → "First Event" unlocks
   - 2+ guests → "Small Gathering" unlocks
   - Beef + Chicken → "Dual Protein" unlocks
   - 6+ guests → "Family Feast" unlocks
   - 10+ guests + both proteins → "Epic Feast" unlocks
3. Document any issues
4. Verify persistence (restart app, milestones remain unlocked)
5. Check graph visualization (nodes positioned correctly)

**Success Metric**: All 5 milestones unlock correctly based on requirements

---

## Recommended Priority Order

### Short Session (1-2 hours)
1. **Option 2**: Position attempt nodes (quick win)
2. **Option 5**: Test end-to-end (find issues early)
3. **Option 3**: Hook up menu actions (finish interactions)

### Medium Session (3-4 hours)
1. **Option 1**: Achievement Dashboard (highest value)
2. **Option 4**: Celebration UI (engagement)
3. **Option 5**: Test end-to-end (validate)

### Long Session (Full day)
Do all options in order: 2 → 5 → 3 → 1 → 4

**Rationale**: Start with quick wins (positioning, testing), finish core interactions (menus), then build user-facing UI (dashboard, celebrations)

---

## Alternative Direction: Add Second Domain

If you want to validate the multi-domain architecture now:

### Gospel Reading Domain (Simplest)
**Why**: Proves engine works for different goal types
**Effort**: High (4-6 hours)
**Impact**: High - validates architecture

**Tasks**:
1. Design Gospel Reading milestone tree
   - Books of Matthew, Mark, Luke, John
   - Chapters as incremental progress
   - Reading streaks
   - Comprehension milestones
2. Create `GospelReadingMilestones.swift`
3. Implement reading session tracking
4. Build reading mode UI (different from graph view)
5. Update dashboard for multi-domain

**Risk**: Adds complexity before UI layer is complete

**Recommendation**: Wait until Achievement Dashboard exists, then add second domain

---

## Technical Debt to Address

### Now (Before Expanding)
- [ ] Position attempt nodes (currently at 0,0)
- [ ] Add achievement dashboard
- [ ] Test unlock mechanics thoroughly

### Soon (Before Phase 2)
- [ ] Add attempt node filtering (by domain, date range)
- [ ] Implement milestone completion tracking
- [ ] Add progress percentage calculations
- [ ] Create template for new domains

### Later (Phase 2+)
- [ ] Cross-domain analytics
- [ ] Kafka integration
- [ ] Template designer
- [ ] Leader dashboard

---

## Open Questions

1. **Attempt Node Positioning**: Near event? Timeline view? Both?
2. **Dashboard Navigation**: New tab? Menu item? Dashboard screen?
3. **Celebration Timing**: Immediate? End of session? Queue?
4. **Milestone Completion**: Auto-complete? Manual? Both?
5. **Multi-Domain UI**: Tabs? Dropdown? Separate screens?

---

## Success Definition

**Phase 1 is complete when**:
- User can see all taco night milestones
- User can track progress toward unlocks
- Milestones unlock correctly based on events
- Unlocks feel rewarding (celebration UI)
- User can complete milestones
- Attempt history is visible and useful

**Current Status**: 60% complete (foundation done, UI pending)

---

## Recommended Next Session

**Focus**: Make achievements visible and rewarding

**Plan**:
1. Start session: Position attempt nodes (30 min)
2. Test unlock flow end-to-end (30 min)
3. Create Achievement Dashboard (2 hours)
4. Add celebration UI (1 hour)
5. Final testing and iteration (30 min)

**Outcome**: Fully functional achievement system ready for user testing

**Deliverable**: ACHIEVEMENT_ENGINE_PHASE1_READY_FOR_TESTING.md

---

**Ready to proceed with**: Dashboard UI, celebration animations, positioning
**Blocked on**: Nothing - all dependencies met
**Risk level**: Low - incremental improvements to working foundation
