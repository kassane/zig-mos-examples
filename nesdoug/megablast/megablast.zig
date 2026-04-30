// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES Megablast: full game port of ProgrammingGamesForTheNES CH13.
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

// Direct OAM buffer access — neslib NMI handler DMAs from $0300 to PPU OAM
const oam: [*]volatile u8 = @ptrFromInt(0x0300);

const PAD_A: u8 = 0x80;
const PAD_B: u8 = 0x40;
const PAD_SELECT: u8 = 0x20;
const PAD_START: u8 = 0x10;
const PAD_LEFT: u8 = 0x02;
const PAD_RIGHT: u8 = 0x01;

const bg_palette: [16]u8 = .{
    0x0F, 0x15, 0x26, 0x37,
    0x0F, 0x19, 0x29, 0x39,
    0x0F, 0x11, 0x21, 0x31,
    0x0F, 0x00, 0x10, 0x30,
};
const sp_palette: [16]u8 = .{
    0x0F, 0x28, 0x21, 0x11,
    0x0F, 0x26, 0x28, 0x17,
    0x0F, 0x38, 0x28, 0x18,
    0x0F, 0x12, 0x22, 0x32,
};
const mountain_tiles: [32]u8 = .{ 1, 2, 3, 4 } ** 8;

// Enemy source data (9 bytes): start_pat, end_pat, sprite_type, dx, dy, score, width, height, attr
// sprite_type: 1 = one sprite, any other value = four sprites
const ENEMY_SRC: [3][9]u8 = .{
    .{ 8, 12, 4, 0, 2, 2, 12, 12, 2 }, // large meteor (type 1)
    .{ 36, 37, 1, 1, 3, 3, 8, 7, 2 }, // small meteor (type 2)
    .{ 16, 19, 1, 2, 3, 6, 8, 8, 3 }, // smart bomb  (type 3)
};

// Game state
var level: u8 = 1;
var score: [3]u8 = .{ 0, 0, 0 }; // BCD-like: score = [2]*10000 + [1]*100 + [0]
var highscore: [3]u8 = .{ 0, 1, 0 }; // initial high score = 100 (displays as "0001000")
var lives: u8 = 5;
var player_dead: u8 = 0;
var flash: u8 = 0;
var shake: u8 = 0;
var enemy_cooldown: u8 = 0;
var enemy_count: u8 = 0;
var display_level: u8 = 0;
var enemy_data: [100]u8 = .{0} ** 100; // 10 enemies × 10 bytes
var star_addrs: [10]u16 = .{0} ** 10;

// Palette cycle state (bg palette 0, colors 1 and 2)
var pal1: u8 = bg_palette[1];
var pal2: u8 = bg_palette[2];

// Deferred VRAM update flags
var score_dirty: bool = false;
var highscore_dirty: bool = false;
var lives_dirty: bool = false;
var level_dirty: bool = false; // show level text
var level_erase_dirty: bool = false; // erase level text

fn ntaddr(row: u8, col: u8) c_int {
    return @intCast(@as(u16, 0x2000) + @as(u16, row) * 32 + col);
}

fn dec2(val: u8, out: *[2]u8) void {
    out[0] = val / 10 + '0';
    out[1] = val % 10 + '0';
}

fn queueScore() void {
    var buf: [7]u8 = undefined;
    var d: [2]u8 = undefined;
    dec2(score[2], &d);
    buf[0] = d[0];
    buf[1] = d[1];
    dec2(score[1], &d);
    buf[2] = d[0];
    buf[3] = d[1];
    dec2(score[0], &d);
    buf[4] = d[0];
    buf[5] = d[1];
    buf[6] = '0';
    nesdoug.multi_vram_buffer_horz(&buf, buf.len, ntaddr(27, 6));
}

fn queueHighScore() void {
    var buf: [7]u8 = undefined;
    var d: [2]u8 = undefined;
    dec2(highscore[2], &d);
    buf[0] = d[0];
    buf[1] = d[1];
    dec2(highscore[1], &d);
    buf[2] = d[0];
    buf[3] = d[1];
    dec2(highscore[0], &d);
    buf[4] = d[0];
    buf[5] = d[1];
    buf[6] = '0';
    nesdoug.multi_vram_buffer_horz(&buf, buf.len, ntaddr(1, 13));
}

fn queueLives() void {
    var row1: [16]u8 = .{0} ** 16;
    var row2: [16]u8 = .{0} ** 16;
    const n: u8 = if (lives > 8) 8 else lives;
    var i: u8 = 0;
    while (i < n) : (i += 1) {
        row1[i * 2] = 5;
        row1[i * 2 + 1] = 6;
        row2[i * 2] = 7;
        row2[i * 2 + 1] = 8;
    }
    nesdoug.multi_vram_buffer_horz(&row1, row1.len, ntaddr(27, 14));
    nesdoug.multi_vram_buffer_horz(&row2, row2.len, ntaddr(28, 14));
}

fn queueLevelText() void {
    var buf: [14]u8 = " L E V E L    ".*;
    var d: [2]u8 = undefined;
    dec2(level, &d);
    buf[12] = d[0];
    buf[13] = d[1];
    nesdoug.multi_vram_buffer_horz(&buf, buf.len, ntaddr(14, 9));
}

fn queueLevelErase() void {
    const blank: [14]u8 = .{0} ** 14;
    nesdoug.multi_vram_buffer_horz(&blank, blank.len, ntaddr(14, 9));
}

fn queueGameOver() void {
    const text = " G A M E  O V E R";
    nesdoug.multi_vram_buffer_horz(text, text.len, ntaddr(14, 7));
}

fn addScore(pts: u8) void {
    const s0 = @as(u16, score[0]) + pts;
    if (s0 >= 100) {
        score[0] = @intCast(s0 - 100);
        const s1 = @as(u16, score[1]) + 1;
        if (s1 >= 100) {
            score[1] = @intCast(s1 - 100);
            const s2 = @as(u16, score[2]) + 1;
            score[2] = @intCast(if (s2 >= 100) s2 - 100 else s2);
        } else {
            score[1] = @intCast(s1);
        }
    } else {
        score[0] = @intCast(s0);
    }
    score_dirty = true;
    if (score[2] > highscore[2] or
        (score[2] == highscore[2] and score[1] > highscore[1]) or
        (score[2] == highscore[2] and score[1] == highscore[1] and score[0] > highscore[0]))
    {
        highscore = score;
        highscore_dirty = true;
    }
}

fn subtractScore(pts: u8) void {
    if (score[0] == 0 and score[1] == 0 and score[2] == 0) return;
    if (score[0] >= pts) {
        score[0] -= pts;
    } else {
        const need = pts - score[0];
        score[0] = 100 - need;
        if (score[1] > 0) {
            score[1] -= 1;
        } else {
            score[1] = 99;
            score[2] = if (score[2] > 0) score[2] - 1 else 0;
        }
    }
    score_dirty = true;
}

fn placeStars() void {
    for (&star_addrs) |*a| {
        const r = neslib.rand8();
        const row: u8 = (r & 0x0F) + 3;
        const col: u8 = r >> 4;
        const addr: u16 = 0x2000 + @as(u16, row) * 32 + col;
        a.* = addr;
        neslib.vram_adr(addr);
        neslib.vram_write("\x0c", 1);
    }
}

fn animateStars(frame: u8) void {
    if (frame & 3 != 0) return;
    const tile: u8 = if ((frame >> 2) & 1 != 0) 13 else 12;
    for (star_addrs) |a| {
        if (a == 0) continue;
        nesdoug.one_vram_buffer(@intCast(tile), @intCast(a));
    }
}

fn setupLevel() void {
    @memset(&enemy_data, 0);
    enemy_cooldown = 20;
    enemy_count = 0;
    display_level = 64;
    level_dirty = true;
    var i: usize = 20;
    while (i < 180) : (i += 1) oam[i] = 0xFF;
    oam[16] = 0xFF;
}

fn displayPlayer() void {
    oam[0] = 196;
    oam[4] = 196;
    oam[8] = 204;
    oam[12] = 204;
    oam[1] = 0;
    oam[5] = 1;
    oam[9] = 2;
    oam[13] = 3;
    oam[2] = 0;
    oam[6] = 0;
    oam[10] = 0;
    oam[14] = 0;
    oam[3] = 120;
    oam[11] = 120;
    oam[7] = 128;
    oam[15] = 128;
}

fn setPlayerShape(pat: u8) void {
    oam[1] = pat;
    oam[5] = pat + 1;
    oam[9] = pat + 2;
    oam[13] = pat + 3;
}

fn spawnEnemy() void {
    if (enemy_cooldown > 0) {
        enemy_cooldown -= 1;
        if (enemy_cooldown != 0) return;
    }
    enemy_cooldown = 1;
    const thresh = (@as(u16, level) + 1) * 4;
    const rnd = neslib.rand8();
    if (rnd >= @as(u8, @truncate(if (thresh > 255) 255 else thresh))) return;
    enemy_cooldown = 20;
    // Find a free slot (enemy_data[slot*10] == 0)
    var slot: u8 = 255;
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        if (enemy_data[@as(usize, i) * 10] == 0) {
            slot = i;
            break;
        }
    }
    if (slot == 255) return;
    enemy_count +%= 1;
    if (enemy_count >= 40) {
        level += 1;
        enemy_count = 0;
        display_level = 64;
        level_dirty = true;
    }
    const rnd2 = neslib.rand8();
    const etype: u8 = if (rnd2 & 0x0F == 0x0F) 3 else (rnd2 & 1) + 1;
    const base = @as(usize, slot) * 10;
    enemy_data[base] = etype;
    @memcpy(enemy_data[base + 1 .. base + 10], &ENEMY_SRC[etype - 1]);
    // 50% chance to negate dx (makes enemy approach from the right)
    if (enemy_data[base + 4] != 0 and neslib.rand8() & 1 != 0)
        enemy_data[base + 4] = (~enemy_data[base + 4]) +% 1;
    const ob: usize = @as(usize, slot) * 16 + 20;
    const one_spr = enemy_data[base + 3] == 1;
    const sp = enemy_data[base + 1];
    const attr = enemy_data[base + 9];
    if (one_spr) {
        const xpos: u8 = (neslib.rand8() & 0x70) + 48;
        oam[ob + 0] = 0;
        oam[ob + 4] = 0xFF;
        oam[ob + 8] = 0xFF;
        oam[ob + 12] = 0xFF;
        oam[ob + 1] = sp;
        oam[ob + 2] = attr;
        oam[ob + 3] = xpos;
    } else {
        const xpos: u8 = (neslib.rand8() & 0xF0) + 48;
        oam[ob + 0] = 0;
        oam[ob + 4] = 0;
        oam[ob + 8] = 8;
        oam[ob + 12] = 8;
        oam[ob + 1] = sp;
        oam[ob + 5] = sp + 1;
        oam[ob + 9] = sp + 2;
        oam[ob + 13] = sp + 3;
        oam[ob + 2] = attr;
        oam[ob + 6] = attr;
        oam[ob + 10] = attr;
        oam[ob + 14] = attr;
        oam[ob + 3] = xpos;
        oam[ob + 11] = xpos;
        oam[ob + 7] = xpos +% 8;
        oam[ob + 15] = xpos +% 8;
    }
}

fn moveEnemies(frame: u8) void {
    const bx = oam[19];
    const by = oam[16];
    const bullet_on = by != 0xFF;
    var slot: u8 = 0;
    while (slot < 10) : (slot += 1) {
        const base = @as(usize, slot) * 10;
        if (enemy_data[base] == 0) continue;
        const ob: usize = @as(usize, slot) * 16 + 20;
        const dy = enemy_data[base + 5];
        const ht = enemy_data[base + 8];
        const wd = enemy_data[base + 7];
        const one_spr = enemy_data[base + 3] == 1;
        // Smart bomb homing: track player X
        if (enemy_data[base] == 3) {
            const sx = oam[ob + 3];
            const px = oam[3];
            const sdx = enemy_data[base + 4];
            if (sdx & 0x80 != 0) {
                // moving left: flip if smart bomb went 32+ pixels left of player
                if (px >= sx and px - sx >= 32)
                    enemy_data[base + 4] = (~sdx) +% 1;
            } else {
                // moving right: flip if smart bomb went 44+ pixels right of player
                if (sx >= px and sx - px >= 44)
                    enemy_data[base + 4] = (~sdx) +% 1;
            }
        }
        // Horizontal movement
        const dx = enemy_data[base + 4];
        if (dx != 0) {
            const nx = oam[ob + 3] +% dx;
            oam[ob + 3] = nx;
            oam[ob + 11] = nx;
            oam[ob + 7] = nx +% 8;
            oam[ob + 15] = nx +% 8;
        }
        // Vertical movement
        const ny = oam[ob] +% dy;
        oam[ob] = ny;
        // Hit bottom (Y + height >= 204)
        if (@as(u16, ny) + ht >= 204) {
            oam[ob + 0] = 0xFF;
            oam[ob + 4] = 0xFF;
            oam[ob + 8] = 0xFF;
            oam[ob + 12] = 0xFF;
            if (enemy_data[base] == 3) {
                flash = 32;
                shake = 32;
            }
            enemy_data[base] = 0;
            subtractScore(1);
            continue;
        }
        if (!one_spr) {
            oam[ob + 4] = ny;
            oam[ob + 8] = ny +% 8;
            oam[ob + 12] = ny +% 8;
        }
        // Sprite animation (every 4 frames)
        if (frame & 3 == 0) {
            const sp_start = enemy_data[base + 1];
            const sp_end = enemy_data[base + 2];
            if (sp_start != sp_end) {
                if (one_spr) {
                    var p = oam[ob + 1] + 1;
                    if (p >= sp_end) p = sp_start;
                    oam[ob + 1] = p;
                } else {
                    var p = oam[ob + 1] +% 4;
                    if (p >= sp_end) p = sp_start;
                    oam[ob + 1] = p;
                    oam[ob + 5] = p + 1;
                    oam[ob + 9] = p + 2;
                    oam[ob + 13] = p + 3;
                }
            }
        }
        // Player collision (only when alive)
        if (player_dead == 0) {
            if (@as(u16, ny) + ht >= 0xC4) {
                const ex = oam[ob + 3];
                const px = oam[3];
                if (px +% 12 >= ex and ex +% wd >= px) {
                    if (lives > 0) lives -= 1;
                    lives_dirty = true;
                    player_dead = 1;
                    oam[ob + 0] = 0xFF;
                    oam[ob + 4] = 0xFF;
                    oam[ob + 8] = 0xFF;
                    oam[ob + 12] = 0xFF;
                    enemy_data[base] = 0;
                    continue;
                }
            }
        }
        // Bullet collision
        if (bullet_on) {
            const ey = ny;
            const ex = oam[ob + 3];
            if (by +% 4 >= ey and @as(u16, ey) + ht > by and
                bx >= ex and @as(u16, ex) + wd > bx)
            {
                oam[16] = 0xFF;
                oam[ob + 0] = 0xFF;
                oam[ob + 4] = 0xFF;
                oam[ob + 8] = 0xFF;
                oam[ob + 12] = 0xFF;
                addScore(enemy_data[base + 6]);
                enemy_data[base] = 0;
            }
        }
    }
}

fn playerActions(pad: u8) void {
    if (player_dead != 0) {
        switch (player_dead) {
            1 => {
                setPlayerShape(20);
                oam[2] = 1;
                oam[6] = 1;
                oam[10] = 1;
                oam[14] = 1;
            },
            5 => setPlayerShape(24),
            10 => setPlayerShape(28),
            15 => setPlayerShape(32),
            20 => {
                if (lives == 0) return;
                setupLevel();
                displayPlayer();
                player_dead = 0;
                lives_dirty = true;
                return;
            },
            else => {},
        }
        player_dead += 1;
        return;
    }
    // Left movement
    if (pad & PAD_LEFT != 0 and oam[3] != 0) {
        const x = oam[3] -% 2;
        oam[3] = x;
        oam[11] = x;
        oam[7] = x +% 8;
        oam[15] = x +% 8;
    }
    // Right movement
    if (pad & PAD_RIGHT != 0 and oam[3] +% 12 != 254) {
        const x = oam[3] +% 2;
        oam[3] = x;
        oam[11] = x;
        oam[7] = x +% 8;
        oam[15] = x +% 8;
    }
    // Fire bullet (only if none on screen)
    if (pad & PAD_A != 0 and oam[16] == 0xFF) {
        oam[16] = 192;
        oam[17] = 4;
        oam[18] = 0;
        oam[19] = oam[3] +% 6;
    }
}

fn movePlayerBullet() void {
    if (oam[16] == 0xFF) return;
    if (oam[16] < 4) {
        oam[16] = 0xFF;
    } else {
        oam[16] -= 4;
    }
}

fn displayTitleScreen() void {
    neslib.ppu_off();
    neslib.oam_clear();
    neslib.vram_adr(0x2000);
    neslib.vram_fill(0, 1024);
    const title = "M E G A  B L A S T";
    neslib.vram_adr(neslib.NTADR_A(6, 4));
    neslib.vram_write(title, title.len);
    const press = "PRESS FIRE TO BEGIN";
    neslib.vram_adr(neslib.NTADR_A(6, 20));
    neslib.vram_write(press, press.len);
    const attr_row: [8]u8 = .{0x05} ** 8;
    neslib.vram_adr(0x23C0 + 8);
    neslib.vram_write(&attr_row, attr_row.len);
    neslib.ppu_on_all();
}

fn displayGameScreen() void {
    neslib.ppu_off();
    neslib.oam_clear();
    oam[16] = 0xFF;
    neslib.vram_adr(0x2000);
    neslib.vram_fill(0, 1024);
    neslib.vram_adr(neslib.NTADR_A(0, 22));
    neslib.vram_write(&mountain_tiles, mountain_tiles.len);
    neslib.vram_adr(neslib.NTADR_A(0, 26));
    neslib.vram_fill(9, 32);
    const score_hdr = "SCORE 0000000";
    neslib.vram_adr(neslib.NTADR_A(0, 27));
    neslib.vram_write(score_hdr, score_hdr.len);
    // Place random background stars directly while PPU is off
    placeStars();
    neslib.ppu_on_all();
    // Activate nesdoug deferred VRAM buffer system
    nesdoug.set_vram_buffer();
}

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);
    neslib.pal_spr(&sp_palette);
    neslib.pal_bright(4);
    neslib.bank_spr(1);

    while (true) {
        // ---- Title screen ----
        displayTitleScreen();
        while (true) {
            neslib.ppu_wait_nmi();
            const p = neslib.pad_poll(0);
            if (p & (PAD_A | PAD_B | PAD_START | PAD_SELECT) != 0) break;
        }
        // Seed RNG from elapsed frame count so each game is different
        neslib.set_rand(@as(c_uint, nesdoug.get_frame_count()));

        // ---- New game setup ----
        score = .{ 0, 0, 0 };
        lives = 5;
        player_dead = 0;
        level = 1;
        flash = 0;
        shake = 0;
        pal1 = bg_palette[1];
        pal2 = bg_palette[2];
        setupLevel(); // initialises enemy_data, cooldowns, display_level, hides sprites
        displayGameScreen(); // draws BG, places stars, activates VRAM buffer
        displayPlayer();
        // Queue initial HUD writes; NMI will flush them on the first ppu_wait_nmi().
        score_dirty = false;
        highscore_dirty = false;
        lives_dirty = false;
        level_dirty = false;
        queueScore();
        queueHighScore();
        queueLives();
        queueLevelText();

        // ---- Main game loop ----
        var gameover_shown: bool = false;
        game_loop: while (true) {
            neslib.ppu_wait_nmi(); // sync to vblank; NMI flushes VRAM buffer

            const frame = nesdoug.get_frame_count();

            // Flush deferred HUD writes queued last frame
            if (score_dirty) {
                score_dirty = false;
                queueScore();
            }
            if (highscore_dirty) {
                highscore_dirty = false;
                queueHighScore();
            }
            if (lives_dirty) {
                lives_dirty = false;
                queueLives();
            }
            if (level_dirty) {
                level_dirty = false;
                queueLevelText();
            }
            if (level_erase_dirty) {
                level_erase_dirty = false;
                queueLevelErase();
            }

            // Game over state machine (lives = 0, explosion already started on frame 1)
            if (lives == 0 and player_dead != 0 and player_dead != 1) {
                if (player_dead == 20 and !gameover_shown) {
                    gameover_shown = true;
                    queueGameOver();
                }
                if (player_dead == 240) break :game_loop;
                player_dead +%= 1;
                updatePalette(frame);
                updateShake();
                animateStars(frame);
                continue :game_loop;
            }

            // Normal per-frame game logic
            const pad = neslib.pad_poll(0);
            playerActions(pad);
            movePlayerBullet();
            spawnEnemy();
            moveEnemies(frame);

            // Level display countdown
            if (display_level > 0) {
                display_level -= 1;
                if (display_level == 0) level_erase_dirty = true;
            }

            updatePalette(frame);
            updateShake();
            animateStars(frame);
        }
        // Loop back to title screen after game over
    }
}

fn updatePalette(frame: u8) void {
    // Swap bg palette colors 1 and 2 every 8 frames for rainbow shimmer
    if (frame & 7 == 0) {
        const tmp = pal1;
        pal1 = pal2;
        pal2 = tmp;
        neslib.pal_col(1, pal1);
        neslib.pal_col(2, pal2);
    }
    // Flash: briefly brighten backdrop on smart bomb ground hit
    if (flash > 0) {
        flash -= 1;
        neslib.pal_col(0, 0x30);
    } else {
        neslib.pal_col(0, 0x0F);
    }
}

fn updateShake() void {
    if (shake > 0) {
        shake -= 1;
        neslib.scroll(@as(u8, (shake & 1) * 4), 0);
    } else {
        neslib.scroll(0, 0);
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
