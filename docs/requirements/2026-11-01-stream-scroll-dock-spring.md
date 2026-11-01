# Streaming scroll responsiveness and Dock spring expansion

## User outcome

- Scrolling the transcript while a response is streaming must remain responsive
  and must not be pulled back to the bottom by the next token.
- Bottom controls, including queued messages, live file changes, attachments
  and errors, must expand with the same interruptible spring used by other DSH
  disclosures. The Dock height, material and entering control must move as one
  surface instead of flashing or stepping through intermediate frames.

## Streaming behavior

- Non-scrolling streaming may continue at the existing per-frame cadence.
- While the user is dragging or the transcript is coasting, token projection is
  coalesced into a lower-frequency background update and automatic tail
  scrolling is suspended.
- Programmatic tail scrolling must not be mistaken for a user scroll and cancel
  follow mode.
- When scroll activity stops, the latest buffered text is painted once and the
  reader either resumes tail following at the bottom or remains at the chosen
  position with the new-content affordance.
- Reduced motion resolves all scheduled work directly without spring or coast
  animations.

## Dock expansion behavior

- The measured Dock canvas and its background material share one disclosure
  spring transaction.
- Queue, live-change, attachment and error rows use the same disclosure spring.
- A material layer never uses a separate fast row transition that makes it
  appear before the control that justified it.
- Rapid state updates are coalesced by the existing state owner; interrupted
  expansion animates from its current presentation to the new destination.

## Non-goals

- Do not slow the network reader or drop terminal/control frames.
- Do not change the established DSH compact visual style.
- A source test or compile is not device evidence for scroll smoothness.
