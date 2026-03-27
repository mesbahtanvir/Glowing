# Calm Technology

A design skill based on *Calm Technology: Principles and Patterns for Non-Intrusive Design* by Amber Case, building on the foundational work of Mark Weiser and John Seely Brown at Xerox PARC (1995).

Calm technology is designed to inform but not demand focus or attention. It moves smoothly between the periphery and center of a user's attention only when necessary.

---

## The 8 Principles

### I. Require the Smallest Possible Amount of Attention

Give people what they need to solve their problem, and nothing more.

- How much of the user's attention does this feature actually need?
- Can you convey the same information with fewer elements, fewer screens, fewer taps?
- Default to showing less. Let users pull more detail on demand.
- Every notification, animation, or modal is a withdrawal from the user's attention budget.

**In practice:**
- Use progressive disclosure — show summary first, detail on tap.
- Avoid splash screens, interstitials, and loading screens that block the user.
- Prefer inline status over full-screen transitions when possible.
- If a process takes time, let the user do other things — don't lock the screen.

### II. Inform and Create Calm

A calm technology informs without overburdening. It moves easily from the periphery of our attention to the center, and back.

- The periphery is where we attune to information without explicitly attending to it.
- Like the hum of a car engine — unnoticed until something changes.
- Technology should live in the periphery until it genuinely needs center-stage attention.

**In practice:**
- Use subtle ambient cues (color shifts, gentle progress indicators) over aggressive alerts.
- Avoid anxiety-inducing language ("Don't miss out!", "Act now!").
- Let the interface feel settled and quiet by default.
- Reserve bold visual treatments (red, modals, haptics) for genuinely urgent events.

### III. Make Use of the Periphery

By placing information in the periphery, users can attune to many more things than if everything demanded center-stage attention.

- Peripheral information is glanceable, ambient, and non-interruptive.
- It enriches awareness without requiring cognitive engagement.
- At any moment, peripheral information can move to the center when the user chooses.

**In practice:**
- Use ambient status indicators: subtle color, iconography, or badge states.
- Dashboards should be scannable at a glance, not require reading.
- Favor background syncing over manual refresh.
- Progress and streaks can be ambient (a gentle glow, a filled ring) rather than celebratory interruptions.

### IV. Amplify the Best of Technology and the Best of Humanity

Design for people first. Machines shouldn't act like humans. Humans shouldn't act like machines. Amplify the best part of each.

- Technology excels at: computation, pattern recognition, consistency, memory, speed.
- Humans excel at: judgment, creativity, empathy, contextual understanding, taste.
- Let the machine do what machines do well. Let the human do what humans do well.

**In practice:**
- AI analysis should surface insights and recommendations — the human decides.
- Don't automate decisions that benefit from human judgment (e.g., routine preferences).
- Present AI results as suggestions, not mandates.
- Let users confirm, edit, and override AI-generated content.

### V. Communicate Without Speaking

Does your product need to rely on text or voice, or can it use a different communication method? Consider how your technology communicates status.

**Communication patterns (from least to most intrusive):**

1. **Status Lights** — Simple color indicators (green/amber/red). Universally understood. Minimal attention cost.
2. **Status Tones** — Brief auditory cues. A positive chime on completion, a somber tone on failure. Quick acknowledgment without visual attention.
3. **Haptic Alerts** — Physical vibration for important information. Felt without looking. Private and non-disruptive to others.
4. **Ambient Awareness** — Environmental cues like background color shifts, subtle animations, or peripheral visual changes.
5. **Contextual Notifications** — Time or location-based alerts delivered precisely when relevant.
6. **Status Shouts** — Loud, urgent alerts. Reserved exclusively for critical events (errors, safety).

**In practice:**
- A simple icon or color change often replaces a paragraph of text.
- Use haptics for time-sensitive confirmations (routine completed, photo captured).
- Avoid text-heavy status messages when a visual indicator suffices.
- Match communication intensity to information urgency.

### VI. Work Even When It Fails

Think about what happens when your technology fails. Does it default to a usable state, or does it break down completely?

- Graceful degradation over catastrophic failure.
- Offline states should still be useful.
- Error states should guide, not dead-end.

**In practice:**
- Cache data locally so the app works without network.
- If AI analysis fails, let the user manually input their profile.
- Error messages should explain what happened and what to do next.
- Never show a blank screen — always have a fallback state.
- Design loading states that feel like natural pauses, not broken experiences.

### VII. The Right Amount of Technology Is the Minimum Needed

What is the minimum amount of technology needed to solve the problem? Less is more.

- Every feature has a maintenance cost, a cognitive cost, and an attention cost.
- Adding technology should reduce complexity for the user, not increase it.
- The best interface is one you barely notice.

**In practice:**
- Before adding a feature, ask: does this reduce user effort, or add to it?
- Prefer leveraging platform capabilities (camera, notifications, health data) over building custom.
- Avoid settings and options for things you can intelligently default.
- One well-designed screen is better than three simple ones.

### VIII. Respect Social Norms

A person's primary task should not be computing, but being human. Technology should adapt to human social contexts, not the other way around.

- Consider where and when the user interacts with your product.
- Morning and evening routines are personal, often shared-space moments.
- Sounds, brightness, and interruptions affect people nearby.

**In practice:**
- Default to silent/haptic notifications in social contexts.
- Respect Do Not Disturb and system quiet hours.
- Don't guilt users for skipping days or breaking streaks.
- Avoid gamification that creates social pressure or shame.
- Camera features should be respectful of privacy — process locally when possible.

---

## Calm Design Checklist

Use this checklist when designing or reviewing any feature:

- [ ] **Attention**: Does this require the minimum attention needed?
- [ ] **Periphery**: Can this information live in the periphery until needed?
- [ ] **Communication**: Am I using the least intrusive communication pattern that works?
- [ ] **Failure**: What happens when this fails? Is there a graceful fallback?
- [ ] **Minimum**: Is this the minimum technology needed to solve the problem?
- [ ] **Humanity**: Does this amplify human capability rather than replace human judgment?
- [ ] **Social**: Does this respect the user's social context and environment?
- [ ] **Calm**: Does the overall experience create calm, not anxiety?

---

## Calm Communication Ladder

When deciding how to communicate information to the user, start at the bottom and only escalate if needed:

```
Level 6: Status Shout     — Urgent, critical (errors, safety)
Level 5: Modal / Alert    — Requires immediate decision
Level 4: Notification     — Time-sensitive, contextual
Level 3: Haptic           — Tactile confirmation, private
Level 2: Tone             — Brief audio acknowledgment
Level 1: Ambient / Visual — Color, icon, badge, subtle animation
Level 0: Invisible        — Background sync, auto-save, silent processing
```

**Default to Level 0-1. Escalate only with justification.**

---

## Applying Calm Technology to This App

Glowing is a grooming and skincare routine app. Its users interact with it during personal morning and evening moments. Calm Technology principles are especially relevant here:

- **Routines are personal rituals.** The app should feel like a quiet companion, not a demanding coach. Gentle reminders over aggressive push notifications.
- **AI analysis should empower, not overwhelm.** Surface insights and let users confirm. Don't flood with data — present the essence.
- **Progress should be ambient.** A streak indicator, a subtle glow, a filled ring — not confetti explosions or shame for missed days.
- **Camera and analysis flows should feel natural.** Guide with light overlays and peripheral cues, not walls of instructional text.
- **Failure is expected.** Poor lighting? Offer gentle guidance. No network? Show cached routines. AI confused? Let the user clarify.
- **Respect the bathroom mirror moment.** Morning routines happen in shared spaces. Keep sounds minimal, respect quiet hours, and never make the user feel judged.

---

*Based on Calm Technology: Principles and Patterns for Non-Intrusive Design by Amber Case (O'Reilly, 2015), extending the foundational work of Mark Weiser and John Seely Brown at Xerox PARC.*
