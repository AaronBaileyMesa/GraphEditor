# Achievement Engine Vision

## Core Concept

A personal achievement engine that transforms life goals into visual progression systems. The app uses graph-based data structures to track mastery, unlock milestones, and provide persistent coaching through Apple Watch.

**Not**: Four separate apps for different activities
**But**: One progression tracking system that works for any goal with discrete attempts and skill progression

## Target Audience

**Primary**: Young men in church programs (parenting/mentorship tool)
**Secondary**: Anyone pursuing personal development across multiple life domains
**Business Model**: Free for personal use, monetize enterprise/analytics layers

## The Four Pillars (Initial Goals)

1. **Physical**: Increase distance ran in 60 seconds
2. **Spiritual**: Read the Gospels from KJV New Testament
3. **Strategic**: Win a chess match
4. **Social**: Host a taco night for a group

These represent well-rounded character development: body, spirit, mind, service.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│              Watch App Layer                        │
│  ┌──────────┬──────────┬──────────┬──────────┐    │
│  │  Taco    │ Running  │  Chess   │  Gospel  │    │
│  │  Night   │   Mode   │   Mode   │  Reading │    │
│  │  Mode    │          │          │   Mode   │    │
│  └──────────┴──────────┴──────────┴──────────┘    │
│              Cross-Domain Dashboard                 │
└─────────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────┐
│           Graph Engine Layer                        │
│  • Attempt Nodes (each session/event)              │
│  • Milestone Nodes (unlockable achievements)       │
│  • Progression Edges (prerequisites, skill gates)  │
│  • User Node (identity across domains)             │
└─────────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────┐
│              Data Layer                             │
│  • Local persistence (current)                     │
│  • Kafka Repository (future - perpetual record)    │
│  • Export for analytics/other apps                 │
└─────────────────────────────────────────────────────┘
```

## Key Principles

### 1. Graph as Data Model, Not Always UI
- The graph structure tracks relationships and progression
- Each mode can have appropriate UX (visual graph, timeline, board view)
- Graph visualization appears primarily in dashboard/"god view"
- During activities, focus on coaching, not network diagrams

### 2. Progression Mechanics
- Every attempt creates a node in the graph
- Completing activities unlocks new milestones
- Visual representation of skill trees and dependencies
- Celebration of progress without manipulation

### 3. Watch as Persistent Companion
- Real-life video game that tracks your progress
- Always-available coaching during activities
- Quick glances show current status and next steps
- Complications surface relevant data per goal

### 4. Data Ownership
- User's achievement data belongs to them
- Feeds into personal Kafka repository
- Can be used by future apps and analytics
- "Your data stays with you forever" as a feature

## Implementation Phases

### Phase 1: Prove The Pattern (Current Priority)
**Goal**: Complete taco night as the first domain in the achievement engine

**Tasks**:
- [x] Basic taco night planning (complete)
- [x] Add progression mechanics to taco night
  - [x] Attempt nodes (each event hosted) - AttemptNode.swift
  - [x] Milestone system (host 1 → unlock host 2, etc.) - TacoNightMilestones.swift
  - [x] Dietary mastery tracking (restrictions handled) - metrics in AttemptNode
  - [x] Menu complexity progression - metrics in AttemptNode
- [x] Core achievement engine (GraphModel+Achievements.swift)
- [ ] Build achievement dashboard UI showing milestone tree
- [ ] Create visualization of attempt history
- [ ] Test with small group (church youth program)

**Current Status**: ✅ **Foundation Complete** (2026-02-25)
- AttemptNode and MilestoneNode types implemented
- Taco Night milestone tree (5 milestones, 4 tiers) working
- Unlock mechanics functional (previous milestones, attempt counts, metric thresholds)
- Graph persistence integrated
- See ACHIEVEMENT_ENGINE_PHASE1_COMPLETE.md for details

**Immediate Next Steps**:
1. Create Achievement Dashboard view for visualizing milestone tree
2. Position attempt nodes (currently stack at 0,0)
3. Add celebration UI when milestones unlock
4. Hook up completion actions in menus

**Success Criteria**:
- Users understand the unlock mechanics
- Hosting multiple events feels rewarding
- Graph visualization makes sense to non-technical users
- System architecture supports adding new domains ✅ **VALIDATED**

### Phase 2: Add Second Domain
**Goal**: Validate that the same engine works for different goal types

**Primary Candidate**: Gospel Reading (simplest progression model)
- Chapter nodes → Book nodes → Testament completion
- Reading sessions as attempt nodes
- Comprehension checkpoints as milestones
- Streak tracking and encouragement

**Tasks**:
- [ ] Design Gospel reading progression tree
- [ ] Build reading mode UI (appropriate for sequential content)
- [ ] Add reading domain to achievement engine
- [ ] Refine dashboard to show multi-domain progress
- [ ] Add cross-domain comparisons and insights

**Success Criteria**:
- Same graph engine supports both social and spiritual domains
- Dashboard effectively shows progress across multiple areas
- Users see value in multi-domain tracking

### Phase 3: Add Physical + Strategic
**Goal**: Complete the four pillars

**Running Mode**:
- Temporal progression (speed over time)
- Distance milestones (60sec runs at increasing distances)
- Training session attempt nodes
- Performance graphs and trends

**Chess Mode**:
- Decision trees for game analysis
- Game attempt nodes with outcomes
- Tactical pattern recognition milestones
- Opening repertoire progression

**Tasks**:
- [ ] Design running progression system
- [ ] Build running mode UI with temporal visualization
- [ ] Design chess progression system
- [ ] Build chess mode UI (board + tree hybrid)
- [ ] Complete four-pillar dashboard

**Success Criteria**:
- All four domains working cohesively
- Users can pursue multiple goals simultaneously
- Watch complications support all domains
- Clear sense of holistic character development

### Phase 4: Extract The Engine
**Goal**: Enable monetization and extensibility

**Infrastructure**:
- [ ] Kafka integration for perpetual storage
- [ ] Template system for custom goals
- [ ] Goal designer interface
- [ ] Data export/import capabilities

**Business Features**:
- [ ] Youth program leader dashboard
  - See group's aggregate progress
  - Identify struggling individuals
  - Celebrate group achievements
- [ ] Enterprise goal tracking
  - Custom training progressions
  - Team analytics
  - Compliance tracking
- [ ] Template marketplace
  - Therapist-designed therapeutic progressions
  - Coach-designed training programs
  - Community-shared goal templates

**Success Criteria**:
- Kafka pipeline handles all achievement data
- Custom goals can be created without code changes
- Leader dashboard provides actionable insights
- First paying customers in enterprise/program space

## Technical Considerations

### Existing Assets
- Graph engine is solid and flexible
- Multi-graph support already exists
- Person nodes + preferences system working
- Physics simulation for visual layout
- Watch app foundation complete

### Gaps to Address
- Progression/unlock mechanics (new)
- Attempt tracking and history (new)
- Milestone definition system (new)
- Cross-domain dashboard (new)
- Template system (Phase 4)
- Kafka integration (Phase 4)

### UI/UX Patterns Needed

**Taco Night**: Visual graph (current approach works)
**Running**: Timeline with branching improvements
**Chess**: Board view + move tree hybrid
**Reading**: Progress bar with comprehension checkpoints
**Dashboard**: Cross-domain visualization showing holistic progress

## Competitive Positioning

**Not Competing With**:
- Strava/Nike Run Club (training optimization)
- YouVersion/Blue Letter Bible (scripture study tools)
- Chess.com/Lichess (competitive chess)
- Party planning apps (event logistics)

**Competing As**:
- Meta-achievement layer above specific activities
- Character development framework
- Personal progression tracking system
- Life coaching companion

**Unique Value**: Holistic view of personal development across physical, spiritual, strategic, and social domains with progression mechanics that make growth tangible and rewarding.

## Success Metrics

### User Engagement
- Daily active usage (check-ins, attempt logging)
- Multi-domain participation (using 2+ pillars)
- Milestone completion rate
- Session length and frequency

### Progression Quality
- Time to first milestone unlock
- User-reported satisfaction with progression pace
- Completion rate of unlocked activities
- Retention after 30/60/90 days

### Social Impact
- Youth program adoption rate
- Group leader satisfaction
- Parent/mentor feedback
- Word-of-mouth growth

## Open Questions

1. **Progression Tuning**: How do we make unlocks feel rewarding without being grindy or manipulative?
2. **Cross-Domain Synergy**: Should achievements in one domain unlock benefits in others?
3. **Social Features**: Compete with friends? Share achievements? Group challenges?
4. **Guidance System**: How much coaching/nudging is helpful vs. annoying?
5. **Data Privacy**: What's the right consent model for Kafka repository?

## Next Steps

1. ✅ ~~Complete current taco night implementation~~
2. ✅ ~~Design and prototype progression mechanics for taco night~~
3. **Create Achievement Dashboard UI** (current priority)
   - Visualize milestone tree with proper layout
   - Show unlock status and requirements
   - Display recent attempts and metrics
   - Add celebration animations
4. **Position attempt nodes** intelligently near linked events
5. **Test with small group** for feedback on progression pace
6. **Iterate based on real usage** before adding more domains

---

**Document Version**: 1.1
**Last Updated**: 2026-02-25
**Status**: Active Development - Phase 1 Foundation Complete, UI Layer Next
