# Project memory

## Product intent & audience

- **TravelXGuide**: a travel guide platform connecting travelers with guides.
- Core entities: users, admins, guides (via guide applications), tours, messages.
- Two user roles at minimum: regular users and admins; guides apply through an application flow.

## Brand personality & voice

- Tone is helpful and direct; responses guide the user through tradeoffs clearly.
- User communicates in casual English.

## Visual design & UX direction

- Monorepo-style layout: `Frontend/` and `Backend/` folders at project root.
- Frontend stack confirmed: **Vite + Tailwind CSS** (Tailwind via Vite plugin, not PostCSS).
- No design system or UI direction inferred yet beyond Tailwind.

## Decisions, constraints & rationale

- Backend originally uses **MongoDB + Mongoose**; a partial Supabase migration exists (5 tables: `users`, `admins`, `guide_applications`, `tours`, `messages`).
- **User constraint**: do not change database, authentication, or backend logic.
- Frontend start command: `npm run dev` (Vite). Frontend builds successfully.
- **Root `package.json` added**: minimal shim that forwards `start`/`dev`/`build` to `Frontend/` so Bolt's preview runner can launch it (preview expects root-level entry).
- Frontend dependencies installed; Backend dependencies still not installed.
- `.env` files still need to be created/fixed for both sides.

## Open questions & assumptions

- **Unresolved**: MongoDB vs Supabase backend decision still pending.
- Backend not yet runnable in Bolt; frontend preview works but backend-dependent features (tours, logins, messages) will fail until backend is up.
- Assumed `MONGODB_URI=mongodb://localhost:27017/travelxguide` if MongoDB is chosen.
- No `.bolt/prompt` file exists; no global authoritative instructions to reference.