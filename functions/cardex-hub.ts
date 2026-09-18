// functions/cardex-hub.ts
//
// CardexHub — the single Durable Object that owns ALL beta state for Cardex:
// users/cards, connections, access requests, messages, rooms + membership,
// posts, stories, blocks, reports, activity and analytics.
//
// Why one instance ("global"): a closed beta is small, and one actor gives us
// strongly consistent cross-user invariants (no duplicate requests, one joined
// room per user, server-side tier clamping, block enforcement) without
// cross-object coordination. SQLite here is durable; WebSockets pushed from
// this object deliver live events to signed-in clients.
//
// Identity: the platform verifies the client's Rork Auth bearer token and
// stamps `X-Rork-User-Id` before the request reaches us. A missing header is a
// guest — every user route requires it. A test harness (env.BETA_TEST_KEY +
// X-Beta-Test-Key/X-Beta-Test-User headers) exists ONLY to allow end-to-end
// curl verification and is dead when the env var is unset.

import { DurableObject } from "cloudflare:workers";

type Env = {
  DO: Fetcher;
  BETA_TEST_KEY?: string;
};

// Swift's JSONDecoder with .secondsSince1970 — epoch seconds on the wire.
const nowSeconds = (): number => Math.floor(Date.now() / 1000);

type CardJSON = {
  id: string;
  details?: { id: string; kind: string; value: string; tier: string }[];
  stories?: { id: string; caption: string; postedAt: number; imageName?: string; imageData?: string | null }[];
  visibility?: string;
  photoData?: string | null;
  [key: string]: unknown;
};

const TIER_RANK: Record<string, number> = { public: 0, connected: 1, trusted: 2 };

export class CardexHub extends DurableObject<Env> {
  private sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;

    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS users (
        uuid TEXT PRIMARY KEY,
        rork_id TEXT UNIQUE NOT NULL,
        card TEXT,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS connections (
        id TEXT PRIMARY KEY,
        user_low TEXT NOT NULL,
        user_high TEXT NOT NULL,
        origin TEXT NOT NULL,
        met_at TEXT NOT NULL,
        met_on INTEGER NOT NULL,
        tier_low_sees_high TEXT NOT NULL,
        tier_high_sees_low TEXT NOT NULL,
        fav_low INTEGER NOT NULL DEFAULT 0,
        fav_high INTEGER NOT NULL DEFAULT 0,
        note_low TEXT NOT NULL DEFAULT '',
        note_high TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        UNIQUE(user_low, user_high)
      );
      CREATE TABLE IF NOT EXISTS requests (
        id TEXT PRIMARY KEY,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        tier TEXT NOT NULL,
        status TEXT NOT NULL,
        context TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        text TEXT NOT NULL,
        sent_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS read_markers (
        user_id TEXT NOT NULL,
        partner_id TEXT NOT NULL,
        last_read_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, partner_id)
      );
      CREATE TABLE IF NOT EXISTS rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        venue TEXT NOT NULL,
        city TEXT NOT NULL,
        blurb TEXT NOT NULL,
        image_name TEXT NOT NULL,
        access TEXT NOT NULL,
        host_id TEXT,
        ticket_price REAL,
        is_broadcasting INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS room_members (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        remote INTEGER NOT NULL DEFAULT 0,
        joined_at INTEGER NOT NULL,
        PRIMARY KEY (room_id, user_id)
      );
      CREATE TABLE IF NOT EXISTS room_pending (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (room_id, user_id)
      );
      CREATE TABLE IF NOT EXISTS room_tickets (
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        paid_at INTEGER NOT NULL,
        PRIMARY KEY (room_id, user_id)
      );
      CREATE TABLE IF NOT EXISTS posts (
        id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL,
        body TEXT NOT NULL,
        image_name TEXT,
        posted_at INTEGER NOT NULL,
        audience TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS post_applause (
        post_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        PRIMARY KEY (post_id, user_id)
      );
      CREATE TABLE IF NOT EXISTS blocks (
        blocker_id TEXT NOT NULL,
        blocked_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (blocker_id, blocked_id)
      );
      CREATE TABLE IF NOT EXISTS reports (
        id TEXT PRIMARY KEY,
        reporter_id TEXT NOT NULL,
        reported_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        subject_id TEXT,
        detail TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        event TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages (recipient_id, sent_at);
      CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages (sender_id, sent_at);
    `);

    this.ensureBetaLobby();
  }

  // The one server-owned room so new beta users always have somewhere real to
  // join. No fake attendees — membership is real only.
  private ensureBetaLobby(): void {
    const existing = this.sql.exec("SELECT id FROM rooms WHERE id = ?", "beta-lobby").toArray();
    if (existing.length > 0) return;
    this.sql.exec(
      `INSERT INTO rooms (id, name, venue, city, blurb, image_name, access, host_id, ticket_price, is_broadcasting, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, 0, ?)`,
      "beta-lobby",
      "Cardex Beta Lobby",
      "Online",
      "Beta",
      "The open room for the Cardex closed beta. Join here to meet other beta members and exchange cards.",
      "warehouse_networking_event",
      "openDoor",
      Date.now(),
    );
  }

  // MARK: - Routing

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.headers.get("Upgrade")?.toLowerCase() === "websocket") {
      return this.handleWebSocket(request);
    }

    try {
      return await this.route(request, url);
    } catch (err) {
      console.error("cardex-hub error", url.pathname, err);
      return this.json({ error: "internal", message: "Something went wrong on the Cardex backend." }, 500);
    }
  }

  private async route(request: Request, url: URL): Promise<Response> {
    const path = url.pathname;
    const method = request.method;

    if (method === "GET" && path === "/ping") {
      return this.json({ ok: true, service: "cardex-hub", now: nowSeconds() });
    }

    const identity = this.resolveIdentity(request);
    if (!identity) {
      return this.json({ error: "unauthenticated", message: "Sign in to Cardex to continue." }, 401);
    }
    const me = await this.ensureUser(identity);

    switch (true) {
      case method === "GET" && path === "/state":
        return this.state(me, url.searchParams.get("opened") === "1");

      case method === "PUT" && path === "/me":
        return this.saveCard(me, await request.json() as { card: CardJSON });

      case method === "GET" && path === "/discover":
        return this.discover(me, url.searchParams.get("q") ?? "");

      case method === "POST" && path === "/exchange/preview":
        return this.exchangePreview(me, await request.json() as { code: string });
      case method === "POST" && path === "/exchange":
        return this.exchange(me, await request.json() as { code: string; place?: string });

      case method === "POST" && path === "/requests":
        return this.createRequest(me, await request.json() as { to: string; tier: string; context?: string });
      case method === "POST" && path.startsWith("/requests/") && path.endsWith("/resolve"): {
        const requestId = path.slice("/requests/".length, -"/resolve".length);
        return this.resolveRequest(me, requestId, await request.json() as { approve: boolean; tier?: string });
      }

      case method === "POST" && path.startsWith("/connections/") && path.endsWith("/grant"): {
        const partner = path.slice("/connections/".length, -"/grant".length);
        return this.grantTier(me, partner, await request.json() as { tier: string });
      }
      case method === "POST" && path.startsWith("/connections/") && path.endsWith("/favorite"): {
        const partner = path.slice("/connections/".length, -"/favorite".length);
        return this.setFavorite(me, partner, (await request.json() as { on: boolean }).on);
      }
      case method === "POST" && path.startsWith("/connections/") && path.endsWith("/note"): {
        const partner = path.slice("/connections/".length, -"/note".length);
        return this.setNote(me, partner, (await request.json() as { note: string }).note);
      }
      case method === "POST" && path.startsWith("/connections/") && path.endsWith("/remove"): {
        const partner = path.slice("/connections/".length, -"/remove".length);
        return this.removeConnection(me, partner);
      }

      case method === "POST" && path === "/messages":
        return this.sendMessage(me, await request.json() as { to: string; text: string });
      case method === "POST" && path === "/read":
        return this.markRead(me, (await request.json() as { partner: string }).partner);

      case method === "POST" && path === "/rooms":
        return this.createRoom(me, await request.json() as RoomInput);
      case method === "POST" && path.startsWith("/rooms/") && path.endsWith("/join"): {
        const roomId = path.slice("/rooms/".length, -"/join".length);
        return this.joinRoom(me, roomId, (await request.json() as { remote?: boolean }).remote === true);
      }
      case method === "POST" && path.startsWith("/rooms/") && path.endsWith("/leave"): {
        const roomId = path.slice("/rooms/".length, -"/leave".length);
        return this.leaveRoom(me, roomId);
      }
      case method === "POST" && path.startsWith("/rooms/") && path.endsWith("/ticket"): {
        const roomId = path.slice("/rooms/".length, -"/ticket".length);
        return this.buyTicket(me, roomId);
      }
      case method === "POST" && path.startsWith("/rooms/") && path.endsWith("/approve"): {
        const roomId = path.slice("/rooms/".length, -"/approve".length);
        return this.doorDecision(me, roomId, (await request.json() as { user: string }).user, true);
      }
      case method === "POST" && path.startsWith("/rooms/") && path.endsWith("/deny"): {
        const roomId = path.slice("/rooms/".length, -"/deny".length);
        return this.doorDecision(me, roomId, (await request.json() as { user: string }).user, false);
      }
      case method === "POST" && path.startsWith("/rooms/") && path.endsWith("/broadcast"): {
        const roomId = path.slice("/rooms/".length, -"/broadcast".length);
        return this.setBroadcast(me, roomId, (await request.json() as { on: boolean }).on);
      }

      case method === "POST" && path === "/posts":
        return this.createPost(me, await request.json() as { body: string; audience: string; imageName?: string | null });
      case method === "POST" && path.startsWith("/posts/") && path.endsWith("/applause"): {
        const postId = path.slice("/posts/".length, -"/applause".length);
        return this.toggleApplause(me, postId);
      }

      case method === "POST" && path === "/block":
        return this.block(me, (await request.json() as { user: string }).user);
      case method === "POST" && path === "/unblock":
        return this.unblock(me, (await request.json() as { user: string }).user);
      case method === "POST" && path === "/report": {
        const body = await request.json() as { user: string; reason: string };
        return this.report(me, body.user, body.reason);
      }

      case method === "POST" && path === "/account/delete":
        return this.deleteAccount(me);

      case method === "POST" && path === "/analytics":
        return this.analytics(me, await request.json() as { event: string });

      default:
        return this.json({ error: "not-found", message: "Unknown endpoint." }, 404);
    }
  }

  // MARK: - Identity

  private resolveIdentity(request: Request): string | null {
    const platform = request.headers.get("X-Rork-User-Id");
    if (platform) return platform;

    const testKey = this.env.BETA_TEST_KEY;
    if (testKey && request.headers.get("X-Beta-Test-Key") === testKey) {
      const testUser = request.headers.get("X-Beta-Test-User");
      if (testUser) return `test:${testUser}`;
    }
    return null;
  }

  private async ensureUser(rorkId: string): Promise<string> {
    const found = this.sql.exec("SELECT uuid FROM users WHERE rork_id = ?", rorkId).toArray();
    if (found.length > 0) return found[0].uuid as string;

    const uuid = crypto.randomUUID();
    this.sql.exec(
      "INSERT INTO users (uuid, rork_id, card, created_at) VALUES (?, ?, NULL, ?)",
      uuid, rorkId, Date.now(),
    );
    this.track(uuid, "account_created", null, "joined Cardex beta");
    return uuid;
  }

  // MARK: - Helpers

  private json(data: unknown, status = 200): Response {
    return Response.json(data, { status });
  }

  private fail(code: string, message: string, status: number): Response {
    return this.json({ error: code, message }, status);
  }

  private row<T>(query: string, ...params: unknown[]): T | null {
    const rows = this.sql.exec<T>(query, ...params).toArray();
    return rows.length > 0 ? rows[0] : null;
  }

  private cardOf(userId: string): CardJSON | null {
    const row = this.row<{ card: string | null }>("SELECT card FROM users WHERE uuid = ?", userId);
    if (!row?.card) return null;
    try {
      const card = JSON.parse(row.card) as CardJSON;
      card.stories = (card.stories ?? []).filter(
        (s) => Date.now() - s.postedAt * 1000 < 24 * 3600 * 1000,
      );
      return card;
    } catch {
      return null;
    }
  }

  private requireCard(userId: string): CardJSON {
    const card = this.cardOf(userId);
    if (!card) throw new HttpError("no-card", "Create your Cardex card first.", 409);
    return card;
  }

  /// Server-side access-tier enforcement: strip every contact detail above the
  /// viewer's tier before the card leaves the backend.
  private tieredCard(card: CardJSON, tier: string, includeStories: boolean): CardJSON {
    const maxRank = TIER_RANK[tier] ?? 0;
    return {
      ...card,
      details: (card.details ?? []).filter((d) => (TIER_RANK[d.tier] ?? 0) <= maxRank),
      stories: includeStories ? card.stories ?? [] : [],
    };
  }

  private pairKey(a: string, b: string): { low: string; high: string } {
    return a < b ? { low: a, high: b } : { low: b, high: a };
  }

  private connectionRow(me: string, partner: string) {
    const { low, high } = this.pairKey(me, partner);
    return this.row<ConnectionRow>(
      "SELECT * FROM connections WHERE user_low = ? AND user_high = ?",
      low, high,
    );
  }

  private isConnected(me: string, partner: string): boolean {
    return this.connectionRow(me, partner) !== null;
  }

  private isBlockedBetween(a: string, b: string): boolean {
    const { low, high } = this.pairKey(a, b);
    const row = this.row<{ blocker_id: string }>(
      "SELECT blocker_id FROM blocks WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)",
      low, high, high, low,
    );
    return row !== null;
  }

  private blockedIDs(me: string): Set<string> {
    const rows = this.sql
      .exec<{ blocked_id: string }>("SELECT blocked_id FROM blocks WHERE blocker_id = ?", me)
      .toArray();
    return new Set(rows.map((r) => r.blocked_id));
  }

  private blockedByIDs(me: string): Set<string> {
    const rows = this.sql
      .exec<{ blocker_id: string }>("SELECT blocker_id FROM blocks WHERE blocked_id = ?", me)
      .toArray();
    return new Set(rows.map((r) => r.blocker_id));
  }

  private visibleUUIDs(me: string): (id: string) => boolean {
    const blocked = this.blockedIDs(me);
    const blockedBy = this.blockedByIDs(me);
    return (id: string) => id !== me && !blocked.has(id) && !blockedBy.has(id);
  }

  private track(userId: string, kind: string, subjectId: string | null, detail: string): void {
    this.sql.exec(
      "INSERT INTO events (id, user_id, kind, subject_id, detail, created_at) VALUES (?, ?, ?, ?, ?, ?)",
      crypto.randomUUID(), userId, kind, subjectId, detail, Date.now(),
    );
  }

  private analyze(userId: string | null, event: string): void {
    this.sql.exec(
      "INSERT INTO analytics (user_id, event, created_at) VALUES (?, ?, ?)",
      userId, event, Date.now(),
    );
  }

  // MARK: - Snapshot

  private async state(me: string, opened: boolean): Promise<Response> {
    const visible = this.visibleUUIDs(me);
    const myCard = this.cardOf(me);

    // Connections — each served with the tier-filtered card of the other side.
    const connRows = this.sql
      .exec<ConnectionRow>(
        "SELECT * FROM connections WHERE user_low = ? OR user_high = ? ORDER BY met_on DESC",
        me, me,
      )
      .toArray();
    const connections = [];
    for (const row of connRows) {
      const partner = row.user_low === me ? row.user_high : row.user_low;
      if (!visible(partner)) continue;
      const partnerCard = this.cardOf(partner);
      if (!partnerCard) continue;
      const sees = row.user_low === me ? row.tier_low_sees_high : row.tier_high_sees_low;
      const pending = this.row<{ id: string }>(
        "SELECT id FROM requests WHERE from_id = ? AND to_id = ? AND status = 'pending'",
        me, partner,
      );
      connections.push({
        id: row.id,
        card: this.tieredCard(partnerCard, sees, true),
        metAt: row.met_at,
        metOn: Math.floor(row.met_on / 1000),
        origin: row.origin,
        isFavorite: row.user_low === me ? row.fav_low === 1 : row.fav_high === 1,
        note: row.user_low === me ? row.note_low : row.note_high,
        grantedTier: sees,
        accessRequestPending: pending !== null,
      });
    }

    // Requests — both directions, each carrying the other person's card.
    const requestRows = this.sql
      .exec<RequestRow>(
        "SELECT * FROM requests WHERE (from_id = ? OR to_id = ?) AND status = 'pending' ORDER BY created_at DESC",
        me, me,
      )
      .toArray();
    const requests = [];
    for (const row of requestRows) {
      const other = row.from_id === me ? row.to_id : row.from_id;
      if (!visible(other)) continue;
      const otherCard = this.cardOf(other);
      if (!otherCard) continue;
      requests.push({
        id: row.id,
        card: this.tieredCard(otherCard, "public", row.from_id === me),
        direction: row.from_id === me ? "outgoing" : "incoming",
        requestedTier: row.tier,
        status: row.status,
        createdAt: Math.floor(row.created_at / 1000),
        context: row.context,
      });
    }

    // Rooms — real membership only. Blocked members are hidden from the list.
    const roomRows = this.sql
      .exec<RoomRow>("SELECT * FROM rooms ORDER BY created_at DESC")
      .toArray();
    const rooms = [];
    for (const room of roomRows) {
      const memberRows = this.sql
        .exec<{ user_id: string; remote: number }>(
          "SELECT user_id, remote FROM room_members WHERE room_id = ? ORDER BY joined_at",
          room.id,
        )
        .toArray()
        .filter((m) => visible(m.user_id));
      const pendingRows = room.host_id === me
        ? this.sql
            .exec<{ user_id: string }>(
              "SELECT user_id FROM room_pending WHERE room_id = ? ORDER BY created_at",
              room.id,
            )
            .toArray()
            .filter((p) => visible(p.user_id))
        : [];
      const membershipRow = this.row<{ user_id: string }>(
        "SELECT user_id FROM room_members WHERE room_id = ? AND user_id = ?",
        room.id, me,
      );
      const pendingMine = this.row<{ user_id: string }>(
        "SELECT user_id FROM room_pending WHERE room_id = ? AND user_id = ?",
        room.id, me,
      );
      rooms.push({
        id: room.id,
        name: room.name,
        venue: room.venue,
        city: room.city,
        blurb: room.blurb,
        imageName: room.image_name,
        // No location services in the beta — distances are not fabricated.
        distanceMiles: 0,
        liveCount: memberRows.length,
        access: room.access,
        membership: membershipRow ? "joined" : pendingMine ? "pending" : "none",
        attendeeIDs: memberRows.map((m) => m.user_id),
        hostID: room.host_id,
        ticketPrice: room.ticket_price,
        pendingAttendeeIDs: pendingRows.map((p) => p.user_id),
        isBroadcasting: room.is_broadcasting === 1,
      });
    }

    // Messages — everything involving me.
    const messageRows = this.sql
      .exec<MessageRow>(
        `SELECT * FROM messages
         WHERE sender_id = ? OR recipient_id = ?
         ORDER BY sent_at ASC LIMIT 1000`,
        me, me,
      )
      .toArray();
    const messages = messageRows.map((m) => ({
      id: m.id,
      senderID: m.sender_id,
      recipientID: m.recipient_id,
      text: m.text,
      sentAt: Math.floor(m.sent_at / 1000),
    }));

    // Posts — audience-filtered server-side.
    const postRows = this.sql
      .exec<PostRow>("SELECT * FROM posts ORDER BY posted_at DESC LIMIT 100")
      .toArray();
    const posts = [];
    for (const post of postRows) {
      if (!this.canSeePost(me, post)) continue;
      if (!visible(post.author_id)) continue;
      const authorCard = this.cardOf(post.author_id);
      if (!authorCard) continue;
      const applause = this.sql
        .exec<{ n: number }>("SELECT COUNT(*) AS n FROM post_applause WHERE post_id = ?", post.id)
        .toArray()[0].n as number;
      const mine = this.row<{ user_id: string }>(
        "SELECT user_id FROM post_applause WHERE post_id = ? AND user_id = ?",
        post.id, me,
      );
      posts.push({
        id: post.id,
        author: this.tieredCard(authorCard, "public", true),
        body: post.body,
        imageName: post.image_name,
        postedAt: Math.floor(post.posted_at / 1000),
        audience: post.audience,
        applauds: applause,
        comments: 0,
        hasApplauded: mine !== null,
      });
    }

    // Discoverable people — real beta users only, public-tier cards, stories off.
    const userRows = this.sql
      .exec<{ uuid: string; card: string }>("SELECT uuid, card FROM users WHERE card IS NOT NULL AND uuid != ?", me)
      .toArray();
    const discoverable = [];
    for (const row of userRows) {
      if (!visible(row.uuid)) continue;
      const card = this.cardOf(row.uuid);
      if (!card || card.visibility === "dark") continue;
      if (this.isConnected(me, row.uuid)) continue;
      discoverable.push(this.tieredCard(card, "public", false));
    }

    // Activity — my recent event feed.
    const eventRows = this.sql
      .exec<EventRow>(
        "SELECT * FROM events WHERE user_id = ? ORDER BY created_at DESC LIMIT 30",
        me,
      )
      .toArray();
    const activity = [];
    for (const event of eventRows) {
      const card = event.subject_id ? this.cardOf(event.subject_id) : myCard;
      if (!card) continue;
      activity.push({
        id: event.id,
        card: this.tieredCard(card, "public", false),
        kind: event.kind,
        detail: event.detail,
        date: Math.floor(event.created_at / 1000),
      });
    }

    const markerRows = this.sql
      .exec<MarkerRow>("SELECT partner_id, last_read_at FROM read_markers WHERE user_id = ?", me)
      .toArray();
    const readMarkers: Record<string, number> = {};
    for (const marker of markerRows) {
      readMarkers[marker.partner_id] = Math.floor(marker.last_read_at / 1000);
    }

    if (opened) this.analyze(me, "app_opened");

    return this.json({
      me: myCard,
      connections,
      requests,
      rooms,
      messages,
      posts,
      discoverable,
      activity,
      blocked: Array.from(this.blockedIDs(me)).map((id) => ({
        id,
        name: this.cardOf(id)?.name ?? "Unknown",
      })),
      readMarkers,
      serverTime: nowSeconds(),
    });
  }

  private canSeePost(me: string, post: PostRow): boolean {
    if (post.author_id === me) return true;
    switch (post.audience) {
      case "everyone":
        return true;
      case "connections":
        return this.isConnected(me, post.author_id);
      case "room":
        return this.shareRoom(me, post.author_id);
      default:
        return false;
    }
  }

  private shareRoom(a: string, b: string): boolean {
    const row = this.row<{ room_id: string }>(
      `SELECT rm.room_id FROM room_members rm
       WHERE rm.user_id = ? AND EXISTS (
         SELECT 1 FROM room_members other WHERE other.room_id = rm.room_id AND other.user_id = ?
       ) LIMIT 1`,
      a, b,
    );
    return row !== null;
  }

  // MARK: - Card

  private async saveCard(me: string, body: { card: CardJSON }): Promise<Response> {
    const card = body.card;
    if (!card || typeof card.name !== "string") {
      return this.fail("invalid-card", "That card could not be saved. Try again.", 400);
    }
    if (!card.name.trim()) {
      return this.fail("invalid-card", "Your card needs a name.", 400);
    }
    const json = JSON.stringify(card);
    if (json.length > 1_500_000) {
      return this.fail("card-too-large", "Your photo is too large. Pick a smaller one.", 413);
    }

    const hadCard = this.cardOf(me) !== null;
    // The server identity is authoritative — the card id IS the beta uuid,
    // so QR payloads and relationship records all resolve to one identity.
    card.id = me;
    this.sql.exec("UPDATE users SET card = ? WHERE uuid = ?", JSON.stringify(card), me);

    if (!hadCard) {
      this.track(me, "cardCreated", null, "You created your card");
      this.analyze(me, "card_completed");
    }

    // My card change can affect what others see (new details, stories).
    this.notifyPartners(me, { type: "peer.updated", userId: me });
    return this.json({ ok: true });
  }

  // MARK: - Exchange (QR)

  private async exchangePreview(me: string, body: { code: string }): Promise<Response> {
    const target = await this.targetForCode(me, body.code);
    const card = this.requireCard(target.uuid);
    return this.json({
      card: this.tieredCard(card, "public", false),
      userUUID: target.uuid,
    });
  }

  private async exchange(me: string, body: { code: string; place?: string }): Promise<Response> {
    const target = await this.targetForCode(me, body.code);
    const existing = this.connectionRow(me, target.uuid);
    if (existing) {
      return this.json({ ok: true, alreadyConnected: true });
    }

    const myCard = this.requireCard(me);
    const theirCard = this.requireCard(target.uuid);
    const id = crypto.randomUUID();
    const { low, high } = this.pairKey(me, target.uuid);
    const meLow = low === me;
    // Exchange grants Connected, clamped by each person's own visibility ceiling.
    const myCeiling = TIER_RANK[this.ceilingOf(myCard)] ?? 1;
    const theirCeiling = TIER_RANK[this.ceilingOf(theirCard)] ?? 1;
    const place = (body.place ?? "Cardex exchange").slice(0, 120);

    this.sql.exec(
      `INSERT INTO connections (id, user_low, user_high, origin, met_at, met_on,
         tier_low_sees_high, tier_high_sees_low, created_at)
       VALUES (?, ?, ?, 'exchange', ?, ?, ?, ?, ?)`,
      id, low, high, place, Date.now(),
      meLow ? "connected" : this.rankToTier(Math.min(1, theirCeiling)),
      meLow ? this.rankToTier(Math.min(1, myCeiling)) : "connected",
      Date.now(),
    );

    this.track(me, "exchanged", target.uuid, place);
    this.track(target.uuid, "exchanged", me, place);
    this.analyze(me, "connection_created");
    this.analyze(target.uuid, "connection_created");
    const firstForMe = this.countConnections(me) === 1;
    const firstForThem = this.countConnections(target.uuid) === 1;
    if (firstForMe) this.analyze(me, "first_exchange");
    if (firstForThem) this.analyze(target.uuid, "first_exchange");

    await this.pushToUsers([me, target.uuid], { type: "connection.new" });
    return this.json({ ok: true, connectionID: id });
  }

  private async targetForCode(me: string, code: string): Promise<{ uuid: string }> {
    const uuid = (code ?? "").replace("cardex://card/", "").trim();
    if (!uuid || uuid === me) {
      throw new HttpError("invalid-code", "That QR code is not a Cardex code.", 400);
    }
    const row = this.row<{ uuid: string }>("SELECT uuid FROM users WHERE uuid = ?", uuid);
    if (!row) throw new HttpError("unknown-code", "That card is not registered in the beta yet.", 404);
    if (this.isBlockedBetween(me, uuid)) {
      throw new HttpError("blocked", "You can't exchange cards with this person.", 403);
    }
    return row;
  }

  private ceilingOf(card: CardJSON): string {
    switch (card.visibility) {
      case "private": return "connected";
      case "dark": return "public";
      default: return "trusted";
    }
  }

  private rankToTier(rank: number): string {
    return rank <= 0 ? "public" : rank === 1 ? "connected" : "trusted";
  }

  private countConnections(userId: string): number {
    return this.sql
      .exec<{ n: number }>(
        "SELECT COUNT(*) AS n FROM connections WHERE user_low = ? OR user_high = ?",
        userId, userId,
      )
      .toArray()[0].n as number;
  }

  // MARK: - Access requests

  private async createRequest(me: string, body: { to: string; tier: string; context?: string }): Promise<Response> {
    const target = await this.targetForRequest(me, body.to);
    const myCard = this.requireCard(me);
    const theirCard = this.requireCard(target);

    // Only ask for what their privacy settings could actually grant, and never
    // above Connected via the cold-request path (Trusted comes after connecting).
    const ceiling = TIER_RANK[this.ceilingOf(theirCard)] ?? 1;
    const asked = Math.min(TIER_RANK[body.tier] ?? 1, ceiling, 1);
    const tier = this.rankToTier(Math.max(0, asked));

    const duplicate = this.row<{ id: string }>(
      "SELECT id FROM requests WHERE from_id = ? AND to_id = ? AND status = 'pending'",
      me, target,
    );
    if (duplicate) return this.json({ ok: true, duplicate: true });
    if (this.isConnected(me, target)) {
      return this.fail("already-connected", "You're already connected with this person.", 409);
    }

    const id = crypto.randomUUID();
    const context = (body.context ?? "Cardex").slice(0, 120);
    this.sql.exec(
      "INSERT INTO requests (id, from_id, to_id, tier, status, context, created_at) VALUES (?, ?, ?, ?, 'pending', ?, ?)",
      id, me, target, tier, context, Date.now(),
    );

    this.track(me, "requestSent", target, context);
    this.track(target, "accessRequest", me, context);
    this.analyze(me, "connection_requested");
    await this.pushToUsers([target], { type: "request.new" });
    return this.json({ ok: true, requestID: id });
  }

  private async targetForRequest(me: string, to: string): Promise<string> {
    const uuid = (to ?? "").trim();
    if (!uuid || uuid === me) throw new HttpError("invalid-target", "That person can't be requested.", 400);
    const row = this.row<{ uuid: string }>("SELECT uuid FROM users WHERE uuid = ?", uuid);
    if (!row) throw new HttpError("unknown-user", "That person isn't in the beta yet.", 404);
    if (this.isBlockedBetween(me, uuid)) throw new HttpError("blocked", "You can't connect with this person.", 403);
    return row.uuid;
  }

  private async resolveRequest(me: string, requestID: string, body: { approve: boolean; tier?: string }): Promise<Response> {
    const row = this.row<RequestRow>("SELECT * FROM requests WHERE id = ?", requestID);
    if (!row) return this.fail("unknown-request", "That request no longer exists.", 404);
    if (row.to_id !== me) {
      return this.fail("forbidden", "Only the recipient can resolve a request.", 403);
    }
    if (row.status !== "pending") return this.json({ ok: true, alreadyResolved: true });
    if (this.isBlockedBetween(me, row.from_id)) {
      this.sql.exec("UPDATE requests SET status = 'declined' WHERE id = ?", requestID);
      return this.fail("blocked", "You can't connect with this person.", 403);
    }

    this.sql.exec("UPDATE requests SET status = ? WHERE id = ?", body.approve ? "approved" : "declined", requestID);

    if (body.approve) {
      const myCard = this.requireCard(me);
      const theirCard = this.requireCard(row.from_id);
      const ceiling = TIER_RANK[this.ceilingOf(myCard)] ?? 1;
      const granted = Math.min(TIER_RANK[body.tier ?? row.tier] ?? 1, ceiling);
      const { low, high } = this.pairKey(row.from_id, me);
      const fromLow = low === row.from_id;
      const existing = this.connectionRow(me, row.from_id);

      if (existing) {
        // Already connected — just raise what they can see of me.
        if (fromLow) {
          this.sql.exec("UPDATE connections SET tier_low_sees_high = ? WHERE id = ?", this.rankToTier(granted), existing.id);
        } else {
          this.sql.exec("UPDATE connections SET tier_high_sees_low = ? WHERE id = ?", this.rankToTier(granted), existing.id);
        }
      } else {
        this.sql.exec(
          `INSERT INTO connections (id, user_low, user_high, origin, met_at, met_on,
             tier_low_sees_high, tier_high_sees_low, created_at)
           VALUES (?, ?, ?, 'request', ?, ?, ?, ?, ?)`,
          crypto.randomUUID(), low, high, row.context, Date.now(),
          fromLow ? this.rankToTier(granted) : "connected",
          fromLow ? "connected" : this.rankToTier(granted),
          Date.now(),
        );
        this.analyze(row.from_id, "connection_created");
        this.analyze(me, "connection_created");
      }

      this.track(me, "accepted", row.from_id, row.context);
      this.track(row.from_id, "accepted", me, row.context);
    }

    await this.pushToUsers([row.from_id, me], { type: "request.resolved" });
    return this.json({ ok: true });
  }

  // MARK: - Connection extras

  private async grantTier(me: string, partnerID: string, body: { tier: string }): Promise<Response> {
    if (!this.isConnected(me, partnerID)) {
      return this.fail("not-connected", "You're not connected with this person.", 404);
    }
    const myCard = this.requireCard(me);
    const ceiling = TIER_RANK[this.ceilingOf(myCard)] ?? 1;
    const granted = Math.max(0, Math.min(TIER_RANK[body.tier] ?? 1, ceiling));

    const { low, high } = this.pairKey(me, partnerID);
    // This changes what THEY can see of ME — my grant, my ceiling.
    if (low === me) {
      this.sql.exec("UPDATE connections SET tier_high_sees_low = ? WHERE user_low = ? AND user_high = ?", this.rankToTier(granted), low, high);
    } else {
      this.sql.exec("UPDATE connections SET tier_low_sees_high = ? WHERE user_low = ? AND user_high = ?", this.rankToTier(granted), low, high);
    }
    await this.pushToUsers([partnerID], { type: "connection.new" });
    return this.json({ ok: true });
  }

  private async setFavorite(me: string, partnerID: string, on: boolean): Promise<Response> {
    const existing = this.connectionRow(me, partnerID);
    if (!existing) return this.fail("not-connected", "You're not connected with this person.", 404);
    const column = existing.user_low === me ? "fav_low" : "fav_high";
    this.sql.exec(`UPDATE connections SET ${column} = ? WHERE id = ?`, on ? 1 : 0, existing.id);
    return this.json({ ok: true });
  }

  private async setNote(me: string, partnerID: string, note: string): Promise<Response> {
    const existing = this.connectionRow(me, partnerID);
    if (!existing) return this.fail("not-connected", "You're not connected with this person.", 404);
    const column = existing.user_low === me ? "note_low" : "note_high";
    this.sql.exec(`UPDATE connections SET ${column} = ? WHERE id = ?`, (note ?? "").slice(0, 500), existing.id);
    return this.json({ ok: true });
  }

  private async removeConnection(me: string, partnerID: string): Promise<Response> {
    const existing = this.connectionRow(me, partnerID);
    if (!existing) return this.json({ ok: true });
    this.sql.exec("DELETE FROM connections WHERE id = ?", existing.id);
    this.sql.exec(
      "DELETE FROM messages WHERE (sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)",
      me, partnerID, partnerID, me,
    );
    this.sql.exec(
      "DELETE FROM requests WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)",
      me, partnerID, partnerID, me,
    );
    this.sql.exec("DELETE FROM read_markers WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)", me, partnerID, partnerID, me);
    await this.pushToUsers([me, partnerID], { type: "state.refresh" });
    return this.json({ ok: true });
  }

  // MARK: - Messaging

  private async sendMessage(me: string, body: { to: string; text: string }): Promise<Response> {
    const text = (body.text ?? "").trim();
    if (!text) return this.fail("empty-message", "Message can't be empty.", 400);
    if (text.length > 4000) return this.fail("message-too-long", "Message is too long.", 400);
    if (!this.isConnected(me, body.to)) {
      return this.fail("not-connected", "You can only message people you've exchanged cards with.", 403);
    }
    if (this.isBlockedBetween(me, body.to)) {
      return this.fail("blocked", "You can't message this person.", 403);
    }

    const id = crypto.randomUUID();
    const sentAt = Date.now();
    this.sql.exec(
      "INSERT INTO messages (id, sender_id, recipient_id, text, sent_at) VALUES (?, ?, ?, ?, ?)",
      id, me, body.to, text, sentAt,
    );
    this.analyze(me, "message_sent");
    this.analyze(body.to, "message_received");

    const message = {
      id, senderID: me, recipientID: body.to, text,
      sentAt: Math.floor(sentAt / 1000),
    };
    await this.pushToUsers([me, body.to], { type: "message.new", message });
    return this.json({ ok: true, message });
  }

  private async markRead(me: string, partner: string): Promise<Response> {
    this.sql.exec(
      `INSERT INTO read_markers (user_id, partner_id, last_read_at) VALUES (?, ?, ?)
       ON CONFLICT(user_id, partner_id) DO UPDATE SET last_read_at = excluded.last_read_at`,
      me, partner, Date.now(),
    );
    return this.json({ ok: true });
  }

  // MARK: - Rooms

  private async createRoom(
    me: string,
    body: { name: string; venue: string; city: string; blurb: string; imageName: string; access: string; ticketPrice?: number | null },
  ): Promise<Response> {
    const name = (body.name ?? "").trim();
    if (!name) return this.fail("invalid-room", "Your event needs a name.", 400);
    const access = ["openDoor", "request", "ticketed"].includes(body.access) ? body.access : "openDoor";

    const id = crypto.randomUUID();
    this.sql.exec(
      `INSERT INTO rooms (id, name, venue, city, blurb, image_name, access, host_id, ticket_price, is_broadcasting, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)`,
      id, name.slice(0, 80),
      (body.venue ?? "Online").slice(0, 80),
      (body.city ?? "Beta").slice(0, 80),
      (body.blurb ?? "").slice(0, 300),
      body.imageName ?? "warehouse_networking_event",
      access, me,
      access === "ticketed" ? Math.max(0, Math.min(500, body.ticketPrice ?? 0)) : null,
      Date.now(),
    );
    this.sql.exec(
      "INSERT INTO room_members (room_id, user_id, remote, joined_at) VALUES (?, ?, 0, ?)",
      id, me, Date.now(),
    );
    this.track(me, "eventCreated", null, name);
    this.analyze(me, "room_created");
    await this.pushAll({ type: "room.updated" });
    return this.json({ ok: true, roomID: id });
  }

  private async joinRoom(me: string, roomId: string, remote: boolean): Promise<Response> {
    const room = this.row<RoomRow>("SELECT * FROM rooms WHERE id = ?", roomId);
    if (!room) return this.fail("unknown-room", "That room no longer exists.", 404);
    if (!this.requireCard(me)) {
      return this.fail("no-card", "Create your Cardex card before joining a room.", 409);
    }

    if (room.access === "ticketed") {
      const ticket = this.row<{ user_id: string }>(
        "SELECT user_id FROM room_tickets WHERE room_id = ? AND user_id = ?",
        roomId, me,
      );
      if (!ticket) return this.fail("ticket-required", "This event needs a ticket.", 402);
    }

    if (room.access === "request" && !remote && room.host_id !== me) {
      const alreadyPending = this.row<{ user_id: string }>(
        "SELECT user_id FROM room_pending WHERE room_id = ? AND user_id = ?",
        roomId, me,
      );
      if (!alreadyPending) {
        this.sql.exec(
          "INSERT INTO room_pending (room_id, user_id, created_at) VALUES (?, ?, ?)",
          roomId, me, Date.now(),
        );
        this.track(me, "joinedRoom", room.host_id, room.name);
        if (room.host_id) await this.pushToUsers([room.host_id], { type: "room.updated" });
        await this.pushToUsers(await this.memberIDs(roomId), { type: "room.updated" });
        return this.json({ ok: true, pending: true });
      }
      return this.json({ ok: true, pending: true });
    }

    return this.admit(me, roomId, remote);
  }

  private async admit(me: string, roomId: string, remote: boolean): Promise<Response> {
    // One joined room per user — leave everywhere else first.
    this.sql.exec("DELETE FROM room_members WHERE user_id = ?", me);
    this.sql.exec("DELETE FROM room_pending WHERE user_id = ?", me);
    this.sql.exec(
      `INSERT INTO room_members (room_id, user_id, remote, joined_at) VALUES (?, ?, ?, ?)
       ON CONFLICT(room_id, user_id) DO UPDATE SET remote = excluded.remote, joined_at = excluded.joined_at`,
      roomId, me, remote ? 1 : 0, Date.now(),
    );
    const room = this.row<RoomRow>("SELECT name FROM rooms WHERE id = ?", roomId);
    this.track(me, "roomJoined", null, room?.name ?? roomId);
    this.analyze(me, "room_joined");
    await this.pushToUsers(await this.memberIDs(roomId), { type: "room.updated" });
    return this.json({ ok: true });
  }

  private async leaveRoom(me: string, roomId: string): Promise<Response> {
    this.sql.exec("DELETE FROM room_members WHERE room_id = ? AND user_id = ?", roomId, me);
    this.sql.exec("DELETE FROM room_pending WHERE room_id = ? AND user_id = ?", roomId, me);
    await this.pushToUsers(await this.memberIDs(roomId), { type: "room.updated" });
    return this.json({ ok: true });
  }

  private async buyTicket(me: string, roomId: string): Promise<Response> {
    const room = this.row<RoomRow>("SELECT * FROM rooms WHERE id = ?", roomId);
    if (!room) return this.fail("unknown-room", "That room no longer exists.", 404);
    if (room.access !== "ticketed") return this.json({ ok: true });
    // BETA: the client runs the clearly-marked simulated processor; the backend
    // records the ticket so membership is a real shared record. No money moves.
    const existing = this.row<{ user_id: string }>(
      "SELECT user_id FROM room_tickets WHERE room_id = ? AND user_id = ?", roomId, me,
    );
    if (!existing) {
      this.sql.exec("INSERT INTO room_tickets (room_id, user_id, paid_at) VALUES (?, ?, ?)", roomId, me, Date.now());
      this.track(me, "ticketPurchased", null, room.name);
    }
    await this.admit(me, roomId, false);
    return this.json({ ok: true });
  }

  private async doorDecision(me: string, roomId: string, userID: string, approve: boolean): Promise<Response> {
    const room = this.row<RoomRow>("SELECT * FROM rooms WHERE id = ?", roomId);
    if (!room) return this.fail("unknown-room", "That room no longer exists.", 404);
    if (room.host_id !== me) return this.fail("forbidden", "Only the host can manage the door.", 403);
    this.sql.exec("DELETE FROM room_pending WHERE room_id = ? AND user_id = ?", roomId, userID);
    if (approve) {
      await this.admit(userID, roomId, false);
      const name = room.name;
      this.track(me, "joinedRoom", userID, name);
    } else {
      await this.pushToUsers([userID], { type: "room.updated" });
    }
    return this.json({ ok: true });
  }

  private async setBroadcast(me: string, roomId: string, on: boolean): Promise<Response> {
    const room = this.row<RoomRow>("SELECT * FROM rooms WHERE id = ?", roomId);
    if (!room) return this.fail("unknown-room", "That room no longer exists.", 404);
    if (room.host_id !== me) return this.fail("forbidden", "Only the host can go live.", 403);
    this.sql.exec("UPDATE rooms SET is_broadcasting = ? WHERE id = ?", on ? 1 : 0, roomId);
    await this.pushAll({ type: "room.updated" });
    return this.json({ ok: true });
  }

  private async memberIDs(roomId: string): Promise<string[]> {
    return this.sql
      .exec<{ user_id: string }>("SELECT user_id FROM room_members WHERE room_id = ?", roomId)
      .toArray()
      .map((r) => r.user_id);
  }

  // MARK: - Feed

  private async createPost(me: string, body: { body: string; audience: string; imageName?: string | null }): Promise<Response> {
    const text = (body.body ?? "").trim();
    if (!text) return this.fail("empty-post", "Write something first.", 400);
    if (text.length > 2000) return this.fail("post-too-long", "Post is too long.", 400);
    const audience = ["everyone", "connections", "room", "private"].includes(body.audience) ? body.audience : "connections";

    const id = crypto.randomUUID();
    this.sql.exec(
      "INSERT INTO posts (id, author_id, body, image_name, posted_at, audience) VALUES (?, ?, ?, ?, ?, ?)",
      id, me, text, body.imageName ?? null, Date.now(), audience,
    );
    await this.pushAll({ type: "feed.new" });
    return this.json({ ok: true, postID: id });
  }

  private async toggleApplause(me: string, postID: string): Promise<Response> {
    const existing = this.row<{ user_id: string }>(
      "SELECT user_id FROM post_applause WHERE post_id = ? AND user_id = ?", postID, me,
    );
    if (existing) {
      this.sql.exec("DELETE FROM post_applause WHERE post_id = ? AND user_id = ?", postID, me);
    } else {
      this.sql.exec("INSERT INTO post_applause (post_id, user_id) VALUES (?, ?)", postID, me);
    }
    await this.pushAll({ type: "feed.new" });
    return this.json({ ok: true });
  }

  // MARK: - Safety

  private async block(me: string, target: string): Promise<Response> {
    const uuid = (target ?? "").trim();
    if (!uuid || uuid === me) return this.fail("invalid-target", "That person can't be blocked.", 400);
    const row = this.row<{ uuid: string }>("SELECT uuid FROM users WHERE uuid = ?", uuid);
    if (!row) return this.fail("unknown-user", "That person isn't in the beta.", 404);

    this.sql.exec(
      "INSERT OR IGNORE INTO blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, ?)",
      me, uuid, Date.now(),
    );
    // Blocking tears the relationship down completely, both sides.
    const existing = this.connectionRow(me, uuid);
    if (existing) this.sql.exec("DELETE FROM connections WHERE id = ?", existing.id);
    this.sql.exec(
      "DELETE FROM messages WHERE (sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)",
      me, uuid, uuid, me,
    );
    this.sql.exec(
      "DELETE FROM requests WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)",
      me, uuid, uuid, me,
    );
    await this.pushToUsers([me, uuid], { type: "state.refresh" });
    return this.json({ ok: true });
  }

  private async unblock(me: string, target: string): Promise<Response> {
    this.sql.exec("DELETE FROM blocks WHERE blocker_id = ? AND blocked_id = ?", me, target);
    return this.json({ ok: true });
  }

  private async report(me: string, target: string, reason: string): Promise<Response> {
    const uuid = (target ?? "").trim();
    if (!uuid) return this.fail("invalid-target", "That report is missing a person.", 400);
    this.sql.exec(
      "INSERT INTO reports (id, reporter_id, reported_id, reason, created_at) VALUES (?, ?, ?, ?, ?)",
      crypto.randomUUID(), me, uuid, (reason ?? "unspecified").slice(0, 500), Date.now(),
    );
    return this.json({ ok: true });
  }

  private async deleteAccount(me: string): Promise<Response> {
    this.sql.exec("DELETE FROM users WHERE uuid = ?", me);
    this.sql.exec("DELETE FROM connections WHERE user_low = ? OR user_high = ?", me, me);
    this.sql.exec("DELETE FROM requests WHERE from_id = ? OR to_id = ?", me, me);
    this.sql.exec("DELETE FROM messages WHERE sender_id = ? OR recipient_id = ?", me, me);
    this.sql.exec("DELETE FROM read_markers WHERE user_id = ? OR partner_id = ?", me, me);
    this.sql.exec("DELETE FROM room_members WHERE user_id = ?", me);
    this.sql.exec("DELETE FROM room_pending WHERE user_id = ?", me);
    this.sql.exec("DELETE FROM room_tickets WHERE user_id = ?", me);
    this.sql.exec("DELETE FROM posts WHERE author_id = ?", me);
    this.sql.exec("DELETE FROM post_applause WHERE user_id = ?", me);
    this.sql.exec("DELETE FROM blocks WHERE blocker_id = ? OR blocked_id = ?", me, me);
    this.sql.exec("DELETE FROM events WHERE user_id = ?", me);
    this.sql.exec("DELETE FROM analytics WHERE user_id = ?", me);
    await this.pushAll({ type: "state.refresh" });
    return this.json({ ok: true });
  }

  private async analytics(me: string, body: { event: string }): Promise<Response> {
    const allowed = new Set([
      "account_created", "card_completed", "first_exchange", "connection_created",
      "room_joined", "message_sent", "message_received", "app_opened",
      "exchange_scanned", "onboarding_finished",
    ]);
    if (allowed.has(body.event)) this.analyze(me, body.event);
    return this.json({ ok: true });
  }

  private async discover(me: string, query: string): Promise<Response> {
    // Kept for future search; the beta client filters the snapshot locally.
    return this.state(me, false);
  }

  // MARK: - WebSockets

  private async handleWebSocket(request: Request): Promise<Response> {
    const identity = this.resolveIdentity(request);
    if (!identity) return this.json({ error: "unauthenticated", message: "Sign in first." }, 401);
    const userId = await this.ensureUser(identity);

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ userId });
    return new Response(null, { status: 101, webSocket: client });
  }

  private async pushToUsers(userIds: string[], event: unknown): Promise<void> {
    const targets = new Set(userIds);
    const payload = JSON.stringify(event);
    for (const socket of this.ctx.getWebSockets()) {
      const attachment = socket.deserializeAttachment() as { userId?: string } | null;
      if (attachment?.userId && targets.has(attachment.userId)) {
        try { socket.send(payload); } catch (err) { console.warn("ws send failed", err); }
      }
    }
  }

  private async pushAll(event: unknown): Promise<void> {
    const payload = JSON.stringify(event);
    for (const socket of this.ctx.getWebSockets()) {
      try { socket.send(payload); } catch (err) { console.warn("ws send failed", err); }
    }
  }

  private notifyPartners(me: string, event: unknown): void {
    const partners = this.sql
      .exec<{ user_low: string; user_high: string }>(
        "SELECT user_low, user_high FROM connections WHERE user_low = ? OR user_high = ?", me, me,
      )
      .toArray()
      .map((r) => (r.user_low === me ? r.user_high : r.user_low));
    this.ctx.waitUntil(this.pushToUsers(partners, event));
  }

  override async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): void {
    if (typeof message === "string" && message === "ping") {
      try { ws.send(JSON.stringify({ type: "pong", now: nowSeconds() })); } catch { /* client gone */ }
    }
  }
}

class HttpError extends Error {
  constructor(public code: string, public userMessage: string, public status: number) {
    super(userMessage);
  }
}

type ConnectionRow = {
  id: string; user_low: string; user_high: string; origin: string; met_at: string;
  met_on: number; tier_low_sees_high: string; tier_high_sees_low: string;
  fav_low: number; fav_high: number; note_low: string; note_high: string;
};
type RequestRow = {
  id: string; from_id: string; to_id: string; tier: string; status: string;
  context: string; created_at: number;
};
type MessageRow = { id: string; sender_id: string; recipient_id: string; text: string; sent_at: number };
type RoomRow = {
  id: string; name: string; venue: string; city: string; blurb: string; image_name: string;
  access: string; host_id: string | null; ticket_price: number | null; is_broadcasting: number;
  created_at: number;
};
type PostRow = { id: string; author_id: string; body: string; image_name: string | null; posted_at: number; audience: string };
type EventRow = { id: string; user_id: string; kind: string; subject_id: string | null; detail: string; created_at: number };
type MarkerRow = { partner_id: string; last_read_at: number };
type RoomInput = {
  name: string; venue: string; city: string; blurb: string; imageName: string;
  access: string; ticketPrice?: number | null;
};
