// ====================================================================
// DIY E-Ink Photo Frame (Slim-Bezel Architectural Edition)
// Designed for:
//   - Waveshare 4.2" e-Paper Module (G) (103.0 x 78.5 mm PCB)
//   - Seeed Studio XIAO ESP32S3 (21.0 x 17.8 mm)
//   - 3.7V LiPo Battery Pouch (up to 62 x 42 x 6 mm)
//   - 6x6mm Tactile Push Button + 4x 12x3mm Neodymium Magnets
// ====================================================================
// Render modes (change `part` below to export individual STLs):
//   part = "exploded";      // Exploded assembly view
//   part = "assembled";     // Closed preview (kickstand stowed flush)
//   part = "standing";      // Desk preview (kickstand deployed at 60 deg)
//   part = "front";         // Front bezel (print face-down, no supports)
//   part = "back";          // Back unibody shell (print flat, no supports)
//   part = "kickstand";     // Wide U-Ring easel kickstand (print flat, no supports)
//   part = "button";        // Captive external button cap (print flat)
// ====================================================================

part = "exploded"; // ["exploded", "assembled", "standing", "front", "back", "kickstand", "button"]
show_electronics = true;

$fn = 64;

// --------------------------------------------------------------------
// 1. Master Dimensions & Minimum-Possible Bezel Geometry (mm)
// --------------------------------------------------------------------
// Physical limit of Waveshare 4.2" Module (G):
//   - Active e-ink image: 84.8 x 63.6 mm
//   - Blue driver PCB:    103.0 x 78.5 mm
// By wrapping a 2.2mm perimeter wall tightly around the 103 x 78.5 mm PCB:
//   - Frame Width  = 108.4 mm (12.0mm slim left/right bezels — minimum physical limit!)
//   - Frame Height = 85.0 mm  (10.7mm slim symmetric top/bottom bezels!)
frame_w  = 108.4;
frame_h  = 85.0;
corner_r = 6.5;

front_h = 4.0;       // Front bezel thickness
back_h  = 11.0;      // Back shell thickness (total frame depth = 15.0 mm)
wall    = 1.8;       // Outer perimeter wall outside rabbet
floor_t = 4.2;       // Rear floor thickness (supports 3.2mm deep 12x3mm magnets + kickstand)
lip_h   = 1.8;       // Interlocking rabbet lip height
lip_tol = 0.20;      // Clearance between front & back rabbet lips

// Waveshare 4.2" Module (G) Window & PCB Pocket (Symmetric All-Around)
win_w = 84.4;        // Visible screen window
win_h = 63.2;
win_bevel = 1.8;     // 45-degree gallery mat bevel

pcb_w = 103.8;       // Module PCB pocket width (103.0 + 0.8mm clearance)
pcb_h = 79.3;        // Module PCB pocket height (78.5 + 0.8mm clearance)
pcb_d = 2.4;         // Pocket depth in front frame for PCB + glass

// Centered symmetrically in both X and Y!
// Wait — because X and Y are 100% symmetric, rotating front_frame around X or Y
// in the assembly preview never shifts the window!
win_x = (frame_w - win_w) / 2;   // 12.0 mm left/right bezel
win_y = (frame_h - win_h) / 2;   // 10.9 mm top/bottom bezel
pcb_x = (frame_w - pcb_w) / 2;   // 2.3 mm outer wall around PCB
pcb_y = (frame_h - pcb_h) / 2;   // 2.85 mm top/bottom wall around PCB

// XIAO ESP32S3 dimensions (21.0 x 17.8 mm)
xiao_w = 18.2;       // Width with clearance
xiao_l = 21.4;       // Length with clearance

// 4x Neodymium Magnets (12mm diameter x 3mm thick)
mag_d     = 12.35;   // 12mm + 0.35mm FDM press/glue clearance
mag_depth = 3.20;    // 3mm + 0.20mm flush recess margin

// Button Placement & 6x6 Tactile Switch Housing
// Ergonomically located on the RIGHT wall at Y = 48.0mm (natural thumb/finger resting
// height, centered between magnets, well above desk surface when standing on kickstand)
btn_y      = 48.0;   // Height along frame_h (85.0 mm total height)

// Wide U-Ring Easel Kickstand (Surface / Switch OLED style)
ks_w       = 64.0;   // Wide 64mm stance so frame never wobbles
ks_h       = 44.0;   // Height of U-frame
ks_leg_w   = 9.0;    // Width of side legs and bottom bar
ks_thick   = 3.0;    // Rigid 3.0mm thickness
ks_corner  = 4.5;    // Outer corner radius
ks_x       = (frame_w - ks_w) / 2;
ks_y       = 8.0;    // Distance from bottom edge (Y = 0)
ks_hinge_y = ks_y + ks_h - 3.6; // Pivot axis 3.6mm from top of legs (3.6mm radial knuckle!)
ks_pin_d   = 3.0;    // 3.0mm diameter pivot pins (matches ks_thick)
ks_pin_len = 2.0;    // Pin extension per side

// --------------------------------------------------------------------
// 2. Reusable Geometric Primitives
// --------------------------------------------------------------------
module rounded_box(w, h, d, r) {
    hull() {
        translate([r, r, 0]) cylinder(r=r, h=d);
        translate([w - r, r, 0]) cylinder(r=r, h=d);
        translate([r, h - r, 0]) cylinder(r=r, h=d);
        translate([w - r, h - r, 0]) cylinder(r=r, h=d);
    }
}

// Chamfered rounded box (ch_bot / ch_top = 45-deg chamfer height)
module chamfered_rounded_box(w, h, d, r, ch_bot=0, ch_top=0) {
    hull() {
        if (ch_bot > 0) {
            translate([r, r, 0]) cylinder(r1=r - ch_bot, r2=r, h=ch_bot);
            translate([w - r, r, 0]) cylinder(r1=r - ch_bot, r2=r, h=ch_bot);
            translate([r, h - r, 0]) cylinder(r1=r - ch_bot, r2=r, h=ch_bot);
            translate([w - r, h - r, 0]) cylinder(r1=r - ch_bot, r2=r, h=ch_bot);
        }
        translate([r, r, ch_bot]) cylinder(r=r, h=d - ch_bot - ch_top);
        translate([w - r, r, ch_bot]) cylinder(r=r, h=d - ch_bot - ch_top);
        translate([r, h - r, ch_bot]) cylinder(r=r, h=d - ch_bot - ch_top);
        translate([w - r, h - r, ch_bot]) cylinder(r=r, h=d - ch_bot - ch_top);
        if (ch_top > 0) {
            translate([r, r, d - ch_top]) cylinder(r1=r, r2=r - ch_top, h=ch_top);
            translate([w - r, r, d - ch_top]) cylinder(r1=r, r2=r - ch_top, h=ch_top);
            translate([r, h - r, d - ch_top]) cylinder(r1=r, r2=r - ch_top, h=ch_top);
            translate([w - r, h - r, d - ch_top]) cylinder(r1=r, r2=r - ch_top, h=ch_top);
        }
    }
}

// Frustum for beveled screen cutout
module beveled_window(w, h, bevel, depth) {
    hull() {
        translate([-bevel, -bevel, -0.05])
            rounded_box(w + bevel * 2, h + bevel * 2, 0.05, 2.0);
        translate([0, 0, bevel])
            rounded_box(w, h, depth, 0.8);
    }
}

// --------------------------------------------------------------------
// 3. PART 1: Slim Front Bezel
//    (Print face-down on build plate: Z = 0 is the front exterior face)
// --------------------------------------------------------------------
module front_frame() {
    lip_inset = wall;
    lip_w = frame_w - lip_inset * 2;
    lip_l = frame_h - lip_inset * 2;
    lip_r = corner_r - lip_inset;

    difference() {
        union() {
            // Main exterior bezel with soft 1.0mm perimeter edge chamfer on front face
            chamfered_rounded_box(frame_w, frame_h, front_h, corner_r, ch_bot=1.0, ch_top=0);

            // Inner interlocking rabbet lip that seats into the back cover
            translate([lip_inset + lip_tol, lip_inset + lip_tol, front_h - 0.01])
                rounded_box(lip_w - lip_tol * 2, lip_l - lip_tol * 2, lip_h, lip_r);

            // 4x Snap-fit retention bumps along top & bottom rabbet lip edges
            for (x_off = [24, frame_w - 24]) {
                translate([x_off, lip_inset + lip_tol, front_h + lip_h * 0.55])
                    rotate([0, 90, 0]) cylinder(r=0.45, h=10, center=true);
                translate([x_off, frame_h - lip_inset - lip_tol, front_h + lip_h * 0.55])
                    rotate([0, 90, 0]) cylinder(r=0.45, h=10, center=true);
            }

            // Button Cap & Switch Hold-Down Tab (on right wall of assembled frame):
            // When front_frame mates with back_cover, this tab locks down into the top
            // of the button guide track and switch cradle, capturing both parts securely!
            translate([wall + lip_tol, btn_y - 4.5, front_h - 0.01])
                cube([2.4, 9.0, lip_h + 1.2]);
        }

        // 45-degree Gallery Mat Bevel Window
        translate([win_x, win_y, 0])
            beveled_window(win_w, win_h, win_bevel, front_h + lip_h + 1);

        // Waveshare 4.2" Module (G) PCB Pocket on inside of bezel
        translate([pcb_x, pcb_y, front_h - pcb_d])
            rounded_box(pcb_w, pcb_h, pcb_d + lip_h + 1, 1.5);
    }
}

// --------------------------------------------------------------------
// 4. PART 2: Back Unibody Shell
//    Coordinate system:
//      - Y = 0 is the BOTTOM edge (USB-C port, kickstand foot)
//      - Y = frame_h (85.0) is the TOP edge (Keyhole wall-hanging hook)
//      - Z = 0 is the exterior rear face (magnets, kickstand, keyhole)
//      - Z = back_h is the open rim that mates with front_frame
// --------------------------------------------------------------------
module back_cover_geom() {
    cav_w = frame_w - 6.4;
    cav_h = frame_h - 6.4;
    cav_r = corner_r - 3.2;

    lip_inset = wall;
    lip_w = frame_w - lip_inset * 2;
    lip_l = frame_h - lip_inset * 2;
    lip_r = corner_r - lip_inset;

    difference() {
        // Outer body with comfortable 1.4mm rear perimeter chamfer
        chamfered_rounded_box(frame_w, frame_h, back_h, corner_r, ch_bot=1.4, ch_top=0);

        // Main internal electronics cavity
        translate([(frame_w - cav_w) / 2, (frame_h - cav_h) / 2, floor_t])
            rounded_box(cav_w, cav_h, back_h, cav_r);

        // Interlocking rabbet step at the top rim to receive front_frame lip
        translate([lip_inset, lip_inset, back_h - lip_h])
            rounded_box(lip_w, lip_l, lip_h + 0.5, lip_r);

        // Matching snap-fit detents inside the top & bottom rabbet walls
        for (x_off = [24, frame_w - 24]) {
            translate([x_off, lip_inset, back_h - lip_h * 0.55])
                rotate([0, 90, 0]) cylinder(r=0.55, h=11, center=true);
            translate([x_off, frame_h - lip_inset, back_h - lip_h * 0.55])
                rotate([0, 90, 0]) cylinder(r=0.55, h=11, center=true);
        }

        // Fingernail pry slot on bottom edge seam (next to USB-C) for easy opening
        translate([frame_w / 2 + 18, -0.5, back_h - 1.2])
            rounded_box(12, wall + 1.5, 1.6, 0.6);

        // 4x Neodymium Magnet Pockets on exterior rear face (12mm x 3mm)
        for (mx = [12.5, frame_w - 12.5]) {
            for (my = [12.5, frame_h - 12.5]) {
                translate([mx, my, -0.1])
                    cylinder(d=mag_d, h=mag_depth + 0.1);
            }
        }

        // ---- Wide U-Ring Easel Kickstand Recess on Rear Face ----
        ks_tol = 0.45;
        difference() {
            union() {
                // Main U-frame recess (depth = ks_thick + 0.25mm = 3.25mm)
                translate([ks_x - ks_tol, ks_y - ks_tol, -0.1])
                    rounded_box(ks_w + ks_tol * 2, ks_h + ks_tol * 2, ks_thick + 0.35, ks_corner + ks_tol);

                // Cylindrical + angled hard-stop pocket around the hinge axis (depth = 3.65mm):
                // Gives full radial clearance for the 3.6mm knuckle to swing open to ~58 degrees
                // before the flat inner stop face of the leg hits the pocket floor!
                for (side_x = [ks_x - ks_tol, ks_x + ks_w - ks_leg_w - ks_tol]) {
                    translate([side_x, ks_hinge_y - 1.5, -0.1])
                        rounded_box(ks_leg_w + ks_tol * 2, (ks_y + ks_h - ks_hinge_y) + 2.5, 3.75, 2.0);
                }
            }

            // Solid flush center island inside the U-ring
            island_w = ks_w - ks_leg_w * 2 - ks_tol * 2;
            island_h = ks_h - ks_leg_w + 2.0;
            translate([ks_x + ks_leg_w + ks_tol, ks_y + ks_leg_w + ks_tol, -0.2])
                rounded_box(island_w, island_h, ks_thick + 2.0, 3.0);
        }

        // Outer Hinge Pin Sockets
        for (px = [ks_x - ks_pin_len, ks_x + ks_w - 0.2]) {
            translate([px, ks_hinge_y, ks_thick / 2])
                rotate([0, 90, 0])
                    cylinder(d=ks_pin_d + 0.45, h=ks_pin_len + 0.4);
        }

        // ---- Kickstand Hinge Full-Extension (58 deg) and Stowed (0 deg) Detents ----
        // Creates a crisp, positive click at full extension (~58 deg) backed by the 58 deg hard-stop.
        // Uses the 44mm U-ring legs as natural cantilever spring arms (flexing inward ~0.25mm).
        for (wx = [ks_x - ks_tol, ks_x + ks_w + ks_tol]) {
            side_sign = (wx < frame_w / 2) ? -1 : 1;

            // 1. Deployed 58-degree Locking Detent Dimple (sharp click at full extension):
            translate([wx + side_sign * 0.20, ks_hinge_y + 1.76, ks_thick / 2 + 1.64])
                sphere(r=0.90, $fn=24);

            // 2. Stowed 0-degree Rest Dimple (relaxes spring tension when folded):
            translate([wx + side_sign * 0.15, ks_hinge_y + 2.32, ks_thick / 2 - 0.62])
                sphere(r=0.85, $fn=24);

            // 3. Smooth Guided Arc Channel from 0 deg to 45 deg (transitions to a 0.18mm crest before the 58 deg snap):
            hull() {
                translate([wx + side_sign * 0.05, ks_hinge_y + 2.32, ks_thick / 2 - 0.62])
                    sphere(r=0.65, $fn=20);
                translate([wx + side_sign * 0.05, ks_hinge_y + 2.08, ks_thick / 2 + 1.20])
                    sphere(r=0.65, $fn=20);
            }
        }

        // Closed-Position Retention Detent Recesses near bottom of kickstand pocket
        for (dx = [ks_x - 0.3, ks_x + ks_w + 0.3]) {
            translate([dx, ks_y + 9.0, ks_thick / 2])
                sphere(r=0.9);
        }

        // Ergonomic Finger Scoop at bottom-center of kickstand bar
        translate([frame_w / 2, ks_y - 1.5, -0.1])
            cylinder(d1=16.0, d2=12.0, h=ks_thick + 0.6);

        // ---- Keyhole Wall-Hanging Slot at TOP-CENTER of Rear Face (Y = frame_h - 16) ----
        // Nail head enters the lower 8.2mm circle at Y = frame_h - 17, then slides UP
        // into the 4.4mm lock slot toward the top edge (Y = frame_h - 11) as the frame settles down.
        translate([frame_w / 2, frame_h - 17.5, -0.1]) {
            cylinder(d=8.2, h=3.2);
            translate([-2.2, 0, 0])
                cube([4.4, 6.5, 3.2]);
            translate([0, 6.5, 0])
                cylinder(d=4.4, h=3.2);
            hull() {
                translate([0, 0, 1.3]) cylinder(d=8.2, h=1.9);
                translate([0, 6.5, 1.3]) cylinder(d=8.2, h=1.9);
            }
        }

        // Recessed USB-C Port Funnel & Opening at BOTTOM-CENTER (Y = 0)
        translate([(frame_w - 14.0) / 2, -0.5, floor_t + 0.2])
            rounded_box(14.0, 1.8, 6.8, 2.0);
        translate([(frame_w - 10.2) / 2, -0.5, floor_t + 1.0])
            rounded_box(10.2, 5.0, 4.8, 1.4);

        // Open-Top Side Action Button Slot + Interior Flange Guide Track on Right Wall (Y = btn_y = 48mm)
        // Open all the way to the top rim (Z = back_h) so the button cap simply drops straight down
        // from the top before the front bezel snaps on and locks it in!
        // 1. Exterior pill slot through the right wall (width Y = 8.6mm, from Z = floor_t + 0.8 to top)
        translate([frame_w - 4.0, btn_y - 4.3, floor_t + 0.8])
            cube([6.0, 8.6, back_h]);
        // 2. Interior vertical guide channel for the button cap's retention flange (width Y = 11.6mm, depth X = 2.6mm)
        translate([frame_w - 2.4 - 2.6, btn_y - 5.8, floor_t])
            cube([2.6, 11.6, back_h]);
    }

    // ---- Internal Component Cradles (sitting on floor_t inside cavity) ----

    // 1. Seeed Studio XIAO ESP32S3 Cradle at bottom center (Y = 3.2..24.6)
    xiao_x = (frame_w - xiao_w) / 2;
    xiao_y = 3.2;
    difference() {
        translate([xiao_x - 1.6, xiao_y, floor_t])
            rounded_box(xiao_w + 3.2, xiao_l + 2.0, 3.6, 1.5);
        translate([xiao_x, xiao_y - 0.5, floor_t + 0.6])
            cube([xiao_w, xiao_l + 1.0, 4.0]);
        translate([frame_w / 2 - 5, xiao_y + 2, floor_t])
            cube([10, xiao_l + 2, 1.2]);
    }

    // 2. Tactile 6x6mm Switch Holder behind the Drop-In Button Track (Y = btn_y = 48mm)
    // Engineered specifically for standard 6x6x5mm or 6x6x6mm tactile switches.
    // - Body sits on 4 solid corner ledges at Z = 1.4mm
    // - Generous 10.4mm wide relief channel + 2.6mm deep well below ledges ensures
    //   flared metal prongs and soldered wires NEVER bind or bottom out!
    // - Open-top design: switch drops straight in from above during assembly.
    sw_w = 8.2;
    sw_len = 13.0;
    sw_x = frame_w - 2.4 - 2.6 - sw_w; // = frame_w - 13.2mm
    translate([sw_x, btn_y - sw_len / 2, floor_t]) {
        difference() {
            // Main solid bracket block
            cube([sw_w, sw_len, back_h - floor_t - lip_h]);

            // 1. Switch body pocket (6.8 x 6.8 mm, open at top)
            // Sits switch body (6.0 x 6.0 mm) on corner ledges at Z = 1.4 mm
            translate([1.2, (sw_len - 6.8) / 2, 1.4])
                cube([6.8, 6.8, back_h]);

            // 2. Wide leg & solder prong relief well (CRITICAL FOR ANGLED PRONGS!)
            // Expands to 10.4 mm width along Y and cuts 2.6 mm below body ledges
            translate([0.8, (sw_len - 10.4) / 2, -1.2])
                cube([7.2, 10.4, back_h]);

            // 3. Front window facing the button cap (+X direction)
            // Allows button cap's pusher nub to contact switch plunger
            translate([sw_w - 1.2, (sw_len - 5.0) / 2, 0.8])
                cube([2.0, 5.0, back_h]);

            // 4. Wire exit tunnel (-X direction into main cavity)
            // Wires route cleanly toward XIAO and battery
            translate([-0.5, (sw_len - 4.6) / 2, 0.0])
                cube([2.5, 4.6, back_h]);
        }
    }

    // 3. LiPo Battery Retention Frame (fits pouches up to 62 x 44 mm)
    bat_w = 62.0;
    bat_h = 44.0;
    bat_x = (frame_w - bat_w) / 2;
    bat_y = xiao_y + xiao_l + 4.5;
    difference() {
        translate([bat_x - 1.6, bat_y - 1.6, floor_t])
            rounded_box(bat_w + 3.2, bat_h + 3.2, 2.2, 3.0);
        translate([bat_x, bat_y, floor_t - 0.1])
            rounded_box(bat_w, bat_h, 3.0, 2.0);
        translate([bat_x - 3, bat_y + 8, floor_t - 0.1])
            cube([bat_w + 6, bat_h - 16, 3.0]);
    }
}

// --------------------------------------------------------------------
// 5. PART 3: Wide U-Ring Architectural Easel Kickstand
//    - True Concentric Barrel Knuckle around the pivot axis (R = 1.5mm)
//      on the inside face so it rotates freely with ZERO cam binding!
//    - Angled 58-degree flat stop face above the barrel that engages
//      the pocket floor only after swinging open a full ~58 degrees!
//    - Flat-bottomed D-profile pivot pins with conical root fillets
// --------------------------------------------------------------------
module d_pin(d, len, root_fillet=1.0) {
    intersection() {
        union() {
            rotate([0, 90, 0])
                cylinder(d1=d, d2=d - 0.5, h=len);
            rotate([0, 90, 0])
                cylinder(d1=d + root_fillet * 2, d2=d, h=root_fillet);
        }
        translate([0, -d, -d / 2])
            cube([len + 1, d * 2, d]);
    }
}

module kickstand() {
    pin_local_y = ks_h - 3.6; // Pivot center is 3.6mm from top of leg
    difference() {
        union() {
            difference() {
                // Full-thickness U-frame
                rounded_box(ks_w, ks_h, ks_thick, ks_corner);

                // Inner U-window
                translate([ks_leg_w, ks_leg_w, -0.1])
                    rounded_box(ks_w - ks_leg_w * 2, ks_h + 2, ks_thick + 0.2, 2.5);

                // 1. Carve the top-inner quadrant above the pivot axis (`Y >= pin_local_y`, `Z >= ks_thick/2`)
                //    and replace it with a concentric cylinder + 58-degree stop bevel so the corner
                //     NEVER binds against the pocket floor when swinging from 0 to 58 degrees!
                translate([-1, pin_local_y, ks_thick / 2])
                    cube([ks_w + 2, 10, ks_thick]);
            }

            // Add back the rounded barrel + 58-degree hard-stop wedge on the top of both legs
            for (lx = [0, ks_w - ks_leg_w]) {
                intersection() {
                    translate([lx, 0, 0])
                        rounded_box(ks_leg_w, ks_h, ks_thick, ks_corner);
                    union() {
                        // Concentric cylinder around pivot axis (R = ks_thick/2 = 1.5mm)
                        // Rotates at constant radius 1.5mm -> zero binding against pocket floor!
                        translate([lx, pin_local_y, ks_thick / 2])
                            rotate([0, 90, 0])
                                cylinder(r=ks_thick / 2, h=ks_leg_w);
                        // Knuckle block with exact 58-degree planar hard-stop face:
                        // When kickstand reaches 58 degrees, this face becomes 100% horizontal
                        // and rests squarely flush against the 3.65mm pocket floor!
                        difference() {
                            translate([lx, pin_local_y, 0])
                                cube([ks_leg_w, 4.0, ks_thick]);
                            translate([lx - 0.5, pin_local_y, ks_thick / 2])
                                rotate([-58, 0, 0])
                                    translate([0, -2.0, 2.15])
                                        cube([ks_leg_w + 1, 12.0, 6.0]);
                        }
                    }
                }
            }

            // Left & Right Flat-Bottomed Root-Filleted Pivot Pins (at Y = pin_local_y)
            translate([0.2, pin_local_y, ks_thick / 2])
                mirror([1, 0, 0])
                    d_pin(ks_pin_d, ks_pin_len + 0.2, root_fillet=1.0);

            translate([ks_w - 0.2, pin_local_y, ks_thick / 2])
                d_pin(ks_pin_d, ks_pin_len + 0.2, root_fillet=1.0);

            // Knuckle Detent Nubs for Full-Extension Click (at radius = 2.4mm, angle = -15 deg relative to pivot)
            // Symmetrically flexes the 44mm U-frame legs inward by ~0.25mm before snapping into the 58 deg dimples!
            translate([0.15, pin_local_y + 2.32, ks_thick / 2 - 0.62])
                sphere(r=0.75, $fn=24);
            translate([ks_w - 0.15, pin_local_y + 2.32, ks_thick / 2 - 0.62])
                sphere(r=0.75, $fn=24);

            // Closed-Position Retention Nubs (overlapped into legs)
            translate([0.15, 9.0, ks_thick / 2]) sphere(r=0.70, $fn=24);
            translate([ks_w - 0.15, 9.0, ks_thick / 2]) sphere(r=0.70, $fn=24);
        }

        // Thumb lip groove on bottom crossbar
        translate([ks_w / 2 - 10, -0.1, ks_thick - 1.0])
            rounded_box(20, 3.2, 1.5, 1.0);
    }
}

// --------------------------------------------------------------------
// 6. PART 4: Captive Pill Button Cap
// --------------------------------------------------------------------
module button_cap() {
    union() {
        // Retention flange (slides vertically in 11.6 x 2.6mm track)
        rounded_box(1.4, 10.6, 5.4, 0.6);

        // Actuator pill head (protrudes 1.6mm outside frame wall)
        translate([1.4, 1.4, 0.8])
            rounded_box(3.8, 7.8, 3.8, 1.4);

        // Cylindrical pusher nub (contacts the center of the tactile switch plunger)
        translate([-1.0, (10.6 - 3.4) / 2, (5.4 - 3.4) / 2])
            rounded_box(1.0, 3.4, 3.4, 0.8);
    }
}

// --------------------------------------------------------------------
// 7. Ghost Reference Models (Waveshare PCB, XIAO ESP32S3, LiPo)
// --------------------------------------------------------------------
module ghost_electronics() {
    color("#1e4d8c", 0.65)
        translate([pcb_x + 0.4, pcb_y + 0.4, back_h - 1.0])
            cube([103.0, 78.5, 1.6]);

    color("#f4efe6", 0.9)
        translate([win_x, win_y, back_h + 0.6])
            cube([win_w, win_h, 1.2]);

    color("#222222", 0.8)
        translate([(frame_w - 17.8) / 2, 3.2, floor_t + 0.6])
            cube([17.8, 21.0, 4.2]);

    color("#c0c0c0", 0.7)
        translate([(frame_w - 58) / 2, 31, floor_t + 0.2])
            rounded_box(58, 40, 5.0, 2.0);
}

// --------------------------------------------------------------------
// 8. Scene & Export Dispatcher
//    Note: Front frame is rotated around the Y-axis (`rotate([0, 180, 0])`)
//    so `Y = 0` is ALWAYS the bottom edge and `Y = frame_h` is ALWAYS the top edge!
// --------------------------------------------------------------------
if (part == "assembled") {
    color("#2b2927") back_cover_geom();
    color("#d4a04a")
        translate([ks_x, ks_y, 0])
            kickstand();
    color("#d4a04a")
        translate([frame_w - 3.8, btn_y - 10.6 / 2, floor_t + 1.2])
            button_cap();
    color("#f2ece1")
        translate([frame_w, 0, back_h + front_h])
            rotate([0, 180, 0])
                front_frame();
    if (show_electronics) ghost_electronics();

} else if (part == "standing") {
    color("#2b2927") back_cover_geom();
    color("#d4a04a")
        translate([ks_x, ks_hinge_y, ks_thick / 2])
            rotate([58, 0, 0])
                translate([0, -(ks_h - 3.6), -ks_thick / 2])
                    kickstand();
    color("#d4a04a")
        translate([frame_w - 3.8, btn_y - 10.6 / 2, floor_t + 1.2])
            button_cap();
    color("#f2ece1")
        translate([frame_w, 0, back_h + front_h])
            rotate([0, 180, 0])
                front_frame();

} else if (part == "exploded") {
    color("#2b2927") back_cover_geom();
    color("#d4a04a")
        translate([ks_x, ks_y, -20])
            kickstand();
    color("#d4a04a")
        translate([frame_w + 10, btn_y - 10.6 / 2, floor_t + 1.2])
            button_cap();
    if (show_electronics)
        translate([0, 0, 18]) ghost_electronics();
    color("#f2ece1")
        translate([frame_w, 0, back_h + front_h + 42])
            rotate([0, 180, 0])
                front_frame();

} else if (part == "front") {
    // Ready to print face-down on bed (Z = 0 is the front exterior face)
    front_frame();

} else if (part == "back") {
    // Ready to print flat on bed (cavity-down so exterior pockets face UP)
    translate([frame_w, 0, back_h])
        rotate([0, 180, 0])
            back_cover_geom();

} else if (part == "kickstand") {
    // Ready to print flat on bed
    kickstand();

} else if (part == "button") {
    // Ready to print flat on inner flange
    translate([1.0, 0, 0])
        rotate([0, -90, 0])
            button_cap();
}
