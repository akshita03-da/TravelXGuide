# Project memory

## Product intent & audience

- **TravelXGuide**: a travel guide platform connecting travelers with guides.
- Core entities: users, admins, guides (via guide applications), tours, messages.
- Two user roles at minimum: regular users and admins; guides apply through an application flow.

## Brand personality & voice

- Tone is helpful and direct; responses guide the user through tradeoffs clearly.
- User communicates in casual English.

## Visual design & UX direction

- Project is split into `Frontend` and `Backend` folders (monorepo-style).
- No specific design direction inferred yet.

## Decisions, constraints & rationale

- Backend originally uses **MongoDB + Mongoose**.
- A migration to **Supabase** was started; 5 tables already created in Supabase: `users`, `admins`, `guide_applications`, `tours`, `messages`.
- **Decision pending**: user is choosing between keeping MongoDB (local PC install) vs continuing Supabase migration.
  - MongoDB: no code changes, but won't run in Bolt environment (no local Mongo server).
  - Supabase: requires backend rewrite from Mongoose to Supabase client, but works immediately in Bolt.
- `npm install` needed in both Frontend and Backend folders.
- `.env` files need to be created/fixed for both sides.

## Open questions & assumptions

- **Unresolved**: Will the user keep MongoDB or proceed with Supabase? Awaiting their choice.
- Assumed `MONGODB_URI=mongodb://localhost:27017/travelxguide` as the local connection string if MongoDB is chosen.
- No `.bolt/prompt` file exists yet; no global authoritative instructions to reference.
- Tech stack details for frontend not yet confirmed (framework, styling).