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
//   part = "standing";      // Desk preview (kickstand deployed at 58 deg)
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
// By wrapping a 2.3mm perimeter wall tightly around the 103.8 x 79.3 mm PCB pocket:
//   - Frame Width  = 108.4 mm (12.0mm slim left/right bezels — minimum physical limit!)
//   - Frame Height = 85.0 mm  (10.9mm slim symmetric top/bottom bezels!)
frame_w  = 108.4;
frame_h  = 85.0;
corner_r = 6.5;

front_h   = 4.0;     // Front bezel thickness (houses display window + PCB pocket)
back_h    = 11.0;    // Back shell thickness (total frame depth = 15.0 mm)
skirt_w   = 1.40;    // Front bezel outer interlocking skirt wall thickness (3-4 perimeters)
lip_h     = 1.8;     // Interlocking skirt/rim height
lip_tol   = 0.15;    // Clearance between front outer skirt & back inner rim
floor_t   = 4.2;     // Rear floor thickness (supports 3.2mm deep 12x3mm magnets + kickstand)

// Waveshare 4.2" Module (G) Window & PCB Pocket (Symmetric All-Around)
win_w     = 84.4;    // Visible screen window
win_h     = 63.2;
win_bevel = 1.8;     // 45-degree gallery mat bevel

pcb_w     = 103.8;   // Module PCB pocket width (103.0 + 0.8mm clearance)
pcb_h     = 79.3;    // Module PCB pocket height (78.5 + 0.8mm clearance)
pcb_d     = 2.4;     // Pocket depth in front bezel for PCB + front e-ink laminate

// Centered symmetrically in both X and Y
win_x = (frame_w - win_w) / 2;   // 12.0 mm left/right bezel
win_y = (frame_h - win_h) / 2;   // 10.9 mm top/bottom bezel
pcb_x = (frame_w - pcb_w) / 2;   // 2.30 mm solid wall around PCB in front bezel
pcb_y = (frame_h - pcb_h) / 2;   // 2.85 mm top/bottom wall around PCB in front bezel

// XIAO ESP32S3 dimensions (21.0 x 17.8 mm)
xiao_w = 18.2;       // Width with clearance
xiao_l = 21.4;       // Length with clearance

// 4x Neodymium Magnets (12mm diameter x 3mm thick)
mag_d     = 12.35;   // 12mm + 0.35mm FDM press/glue clearance
mag_depth = 3.20;    // 3mm + 0.20mm flush recess margin

// Button Placement & Sideways 6x6 Tactile Switch Housing
// Ergonomically located on the RIGHT wall at Y = 48.0mm (natural thumb/finger height,
// centered between magnets, well above desk surface when standing on kickstand)
btn_y      = 48.0;

// Wide U-Ring Easel Kickstand (Surface / Switch OLED style)
ks_w       = 64.0;   // Wide 64mm stance so frame never wobbles
ks_h       = 44.0;   // Height of U-frame
ks_leg_w   = 9.0;    // Width of side legs and bottom bar
ks_thick   = 3.0;    // Rigid 3.0mm thickness
ks_corner  = 4.5;    // Bottom outer corner radius
ks_top_r   = 0.8;    // Top knuckle outer corner radius (keeps side faces flat up to Y=43.2mm)
ks_x       = (frame_w - ks_w) / 2;
ks_y       = 8.0;    // Distance from bottom edge (Y = 0)
ks_hinge_y = ks_y + ks_h - 3.6; // Pivot axis 3.6mm from top of legs (Y = 48.4mm)
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

// Box with distinct bottom-edge (Y=0) and top-edge (Y=h) corner radii in XY
module asym_rounded_box(w, h, d, r_bot, r_top) {
    hull() {
        translate([r_bot, r_bot, 0]) cylinder(r=r_bot, h=d);
        translate([w - r_bot, r_bot, 0]) cylinder(r=r_bot, h=d);
        translate([r_top, h - r_top, 0]) cylinder(r=r_top, h=d);
        translate([w - r_top, h - r_top, 0]) cylinder(r=r_top, h=d);
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
//    - Print face-down on build plate (Z = 0 is the front exterior face)
//    - Z = 0.0 .. 1.6mm: Gallery bevel window (84.4 x 63.2mm)
//    - Z = 1.6 .. 4.0mm: Waveshare PCB pocket (103.8 x 79.3mm, 2.30mm wall)
//    - Z = 4.0 .. 5.8mm: Sturdy 1.40mm thick outer interlocking skirt that
//      slips over the back cover's 1.65mm inner rim and clamps the PCB edges!
// --------------------------------------------------------------------
module front_frame() {
    skirt_inner_w = frame_w - skirt_w * 2; // 105.6 mm (> 103.8mm PCB pocket -> zero overhang!)
    skirt_inner_h = frame_h - skirt_w * 2; // 82.2 mm (> 79.3mm PCB pocket -> zero overhang!)
    skirt_inner_r = corner_r - skirt_w;

    difference() {
        // Main exterior bezel + outer interlocking skirt (Z = 0 .. front_h + lip_h = 5.8mm)
        chamfered_rounded_box(frame_w, frame_h, front_h + lip_h, corner_r, ch_bot=1.0, ch_top=0);

        // 45-degree Gallery Mat Bevel Window
        translate([win_x, win_y, 0])
            beveled_window(win_w, win_h, win_bevel, front_h + 1.0);

        // Waveshare 4.2" Module (G) PCB Pocket on inside of bezel (Z = 1.6 .. 4.05mm)
        translate([pcb_x, pcb_y, front_h - pcb_d])
            rounded_box(pcb_w, pcb_h, pcb_d + 0.1, 1.5);

        // Inner cutout of the outer interlocking skirt (Z = 4.0 .. 5.85mm)
        translate([skirt_w, skirt_w, front_h])
            rounded_box(skirt_inner_w, skirt_inner_h, lip_h + 0.5, skirt_inner_r);
    }

    // 4x Snap-fit retention beads on the inside of the top & bottom outer skirt walls
    for (x_off = [24, frame_w - 24]) {
        translate([x_off, skirt_w, front_h + lip_h * 0.55])
            rotate([0, 90, 0]) cylinder(r=0.40, h=10, center=true, $fn=24);
        translate([x_off, frame_h - skirt_w, front_h + lip_h * 0.55])
            rotate([0, 90, 0]) cylinder(r=0.40, h=10, center=true, $fn=24);
    }
}

// --------------------------------------------------------------------
// 4. PART 2: Back Unibody Shell
//    Coordinate system (and print orientation!):
//      - Z = 0 is the exterior rear face (sits flat on the build plate!)
//      - Z = back_h (11.0) is the open top rim that mates with front_frame
//      - Y = 0 is the BOTTOM edge (USB-C port, kickstand foot)
//      - Y = frame_h (85.0) is the TOP edge (Keyhole wall-hanging hook)
// --------------------------------------------------------------------
module back_cover_geom() {
    cav_wall = 3.2; // 3.2mm perimeter wall thickness
    cav_w = frame_w - cav_wall * 2; // 102.0 mm
    cav_h = frame_h - cav_wall * 2; // 78.6 mm
    cav_r = corner_r - cav_wall;    // 3.3 mm

    // Upstanding inner rim at Z = 9.2 .. 11.0mm (mates inside front_frame's 1.40mm outer skirt):
    // Inset from outer wall by skirt_w + lip_tol = 1.55mm -> rim thickness = 3.20 - 1.55 = 1.65mm!
    rim_inset = skirt_w + lip_tol; // 1.55 mm
    rim_w = frame_w - rim_inset * 2; // 105.3 mm
    rim_h = frame_h - rim_inset * 2; // 81.9 mm
    rim_r = corner_r - rim_inset;    // 4.95 mm

    difference() {
        union() {
            // Lower body (Z = 0 .. 9.2mm) with comfortable 1.2mm rear perimeter chamfer
            chamfered_rounded_box(frame_w, frame_h, back_h - lip_h, corner_r, ch_bot=1.2, ch_top=0);

            // Upstanding 1.65mm-thick inner interlocking rim (Z = 9.0 .. 11.0mm)
            translate([rim_inset, rim_inset, back_h - lip_h - 0.2])
                rounded_box(rim_w, rim_h, lip_h + 0.2, rim_r);
        }

        // Main internal electronics cavity (Z = floor_t = 4.2mm to top)
        translate([cav_wall, cav_wall, floor_t])
            rounded_box(cav_w, cav_h, back_h, cav_r);

        // Matching snap-fit detent grooves on the outside of the top & bottom inner rim walls
        for (x_off = [24, frame_w - 24]) {
            translate([x_off, rim_inset, back_h - lip_h * 0.45])
                rotate([0, 90, 0]) cylinder(r=0.50, h=11, center=true, $fn=24);
            translate([x_off, frame_h - rim_inset, back_h - lip_h * 0.45])
                rotate([0, 90, 0]) cylinder(r=0.50, h=11, center=true, $fn=24);
        }

        // Fingernail pry slot on bottom edge seam (next to USB-C) for easy opening
        translate([frame_w / 2 + 18, -0.5, back_h - lip_h - 0.8])
            rounded_box(12, skirt_w + 1.0, 1.2, 0.5);

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
                // Uses asym_rounded_box so the top knuckle walls stay flat all the way to the top!
                translate([ks_x - ks_tol, ks_y - ks_tol, -0.1])
                    asym_rounded_box(
                        ks_w + ks_tol * 2,
                        ks_h + ks_tol * 2,
                        ks_thick + 0.35,
                        ks_corner + ks_tol,
                        ks_top_r + ks_tol
                    );

                // Deepened hinge knuckle pocket around the pivot axis (depth = 3.65mm):
                // Gives full radial clearance for the barrel + 58-degree planar hard stop!
                for (side_x = [ks_x - ks_tol, ks_x + ks_w - ks_leg_w - ks_tol]) {
                    translate([side_x, ks_hinge_y - 1.5, -0.1])
                        rounded_box(ks_leg_w + ks_tol * 2, (ks_y + ks_h - ks_hinge_y) + 2.5, 3.75, ks_top_r + ks_tol);
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

        // ---- Kickstand Hinge Full-Extension (58 deg) and Stowed (0 deg) Detent Cups ----
        // Knuckle nubs sit at radius r = 2.30mm, angle = -12 deg (stowed) -> +46 deg (at 58 deg open).
        // The two cups are separated by 2.23mm center-to-center, leaving a solid 0.73mm wide flat land
        // (crest) on the pocket side wall so the 44mm kickstand legs flex inward by 0.25mm and SNAP
        // crisply into the 58-degree cup right as the planar stop face meets the pocket floor!
        for (wx = [ks_x - ks_tol, ks_x + ks_w + ks_tol]) {
            side_sign = (wx < frame_w / 2) ? -1 : 1;

            // 1. Deployed 58-degree Locking Detent Cup (0.40mm deep into flat pocket wall):
            translate([wx - side_sign * 0.50, ks_hinge_y + 1.60, ks_thick / 2 + 1.65])
                sphere(r=0.90, $fn=28);

            // 2. Stowed 0-degree Rest Detent Cup (0.40mm deep, zero spring preload when closed):
            translate([wx - side_sign * 0.50, ks_hinge_y + 2.25, ks_thick / 2 - 0.48])
                sphere(r=0.90, $fn=28);
        }

        // Closed-Position Retention Detent Recesses near bottom of kickstand pocket
        for (dx = [ks_x - 0.3, ks_x + ks_w + 0.3]) {
            translate([dx, ks_y + 9.0, ks_thick / 2])
                sphere(r=0.9, $fn=24);
        }

        // Ergonomic Finger Scoop at bottom-center of kickstand bar
        translate([frame_w / 2, ks_y - 1.5, -0.1])
            cylinder(d1=16.0, d2=12.0, h=ks_thick + 0.6);

        // ---- Keyhole Wall-Hanging Slot at TOP-CENTER of Rear Face (Y = frame_h - 17.5) ----
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

        // ---- Drop-In Right-Side Action Button Slot + Recessed Switch Floor (Y = btn_y = 48mm) ----
        // At X = 96..106.6mm, Y = 42..54mm, there is no magnet or kickstand underneath, so we recess
        // the button & switch floor by 1.0mm down to Z = 3.20mm (leaving a solid 3.20mm rear floor!).
        // This lets a standard 6x6mm switch sit sideways (plunger facing +X) from Z = 3.2 to 9.2mm,
        // 1.4mm safely below the Waveshare PCB!
        // 1. Local floor recess (Z = 3.20mm to top) for the switch cradle and button flange track:
        translate([frame_w - 9.4, btn_y - 5.8, 3.20])
            cube([7.6, 11.6, back_h]);

        // 2. Interior vertical guide channel for the button cap's 1.4mm retention flange
        //    Spans X = 104.2 .. 106.6mm (2.4mm wide -> 1.0mm horizontal stroke), Y = 42.2 .. 53.8mm:
        translate([frame_w - 4.2, btn_y - 5.8, 3.20])
            cube([2.4, 11.6, back_h]);

        // 3. Exterior pill slot through the right wall (X = 106.6 .. 108.4mm, Y = 43.8 .. 52.2mm):
        //    Starts at Z = 3.20mm (coplanar with track floor) and opens to Z = 9.2mm so the
        //    flat-bottomed button cap drops straight in from above, and front_frame's 1.40mm
        //    outer skirt closes the top of the slot when snapped shut!
        translate([frame_w - 2.0, btn_y - 4.2, 3.20])
            cube([3.0, 8.4, back_h]);
    }

    // ---- Internal Component Cradles (overlapped into floor so mesh is 100% single-shell!) ----

    // 1. Seeed Studio XIAO ESP32S3 Cradle at bottom center (Y = 3.2..24.6)
    xiao_x = (frame_w - xiao_w) / 2;
    xiao_y = 3.2;
    difference() {
        translate([xiao_x - 1.6, xiao_y, floor_t - 0.2])
            rounded_box(xiao_w + 3.2, xiao_l + 2.0, 3.8, 1.5);
        translate([xiao_x, xiao_y - 0.5, floor_t + 0.6])
            cube([xiao_w, xiao_l + 1.0, 4.0]);
        translate([frame_w / 2 - 5, xiao_y + 2, floor_t - 0.3])
            cube([10, xiao_l + 2, 1.5]);
    }

    // 2. Sideways 6x6mm Tactile Switch Cradle (Plunger facing +X toward Button Cap, Y = btn_y = 48mm)
    //    - Sits switch upright on the Z = 3.20mm recessed floor (switch top is at Z = 9.20mm).
    //    - Plunger protrudes through the 4.6mm front window (+X) to meet the button cap's pusher nub.
    //    - Side walls end 0.5mm before the back of the switch body so the 4 angled metal prongs exiting
    //      the back corners (-X) flare into 100% open air with zero binding!
    //    - A central 2.6mm wide backstop buttress rib (between the 4.5x6.5mm pin grid) supports the
    //      center of the switch body against button presses.
    union() {
        // Left & right L-shaped side/front retention shoulders (captures 6.0 x 3.6mm switch body):
        for (sy = [-1, 1]) {
            // Side guide wall (Y = btn_y +/- 3.2mm, thickness 1.4mm, from X = 99.6 to 104.2mm):
            translate([frame_w - 8.8, btn_y + (sy > 0 ? 3.2 : -4.6), 3.0])
                cube([4.6, 1.4, 6.2]);
            // Front retaining shoulder (X = 103.0 to 104.2mm, leaves 4.6mm central window for plunger):
            translate([frame_w - 5.4, btn_y + (sy > 0 ? 2.3 : -4.6), 3.0])
                cube([1.2, 2.3, 6.2]);
        }

        // Central backstop buttress rib behind switch center (X = 96.6 to 99.15mm, Y = btn_y - 1.3 .. +1.3mm):
        // Sits cleanly between the left and right pairs of switch legs while anchoring the switch body!
        translate([frame_w - 11.8, btn_y - 1.3, 3.0])
            cube([2.65, 2.6, 6.2]);
    }

    // 3. LiPo Battery Retention Frame (fits pouches up to 62 x 44 mm)
    bat_w = 62.0;
    bat_h = 44.0;
    bat_x = (frame_w - bat_w) / 2;
    bat_y = xiao_y + xiao_l + 4.5;
    difference() {
        translate([bat_x - 1.6, bat_y - 1.6, floor_t - 0.2])
            rounded_box(bat_w + 3.2, bat_h + 3.2, 2.4, 3.0);
        translate([bat_x, bat_y, floor_t - 0.3])
            rounded_box(bat_w, bat_h, 3.2, 2.0);
        translate([bat_x - 3, bat_y + 8, floor_t - 0.3])
            cube([bat_w + 6, bat_h - 16, 3.2]);
    }
}

// --------------------------------------------------------------------
// 5. PART 3: Wide U-Ring Architectural Easel Kickstand
//    - Flat outer knuckle walls (ks_top_r = 0.8mm) so pins & detent nubs
//      root directly into the solid leg!
//    - True Concentric Barrel Knuckle around the pivot axis (R = 1.5mm)
//      on the inside face so it rotates freely with ZERO cam binding!
//    - Exact 58-degree planar hard-stop face above the barrel!
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
    pin_local_y = ks_h - 3.6; // Pivot center is at Y = 40.4mm (3.6mm from top of leg)
    difference() {
        union() {
            difference() {
                // Full-thickness U-frame with 4.5mm bottom corners and 0.8mm top knuckle corners
                asym_rounded_box(ks_w, ks_h, ks_thick, ks_corner, ks_top_r);

                // Inner U-window
                translate([ks_leg_w, ks_leg_w, -0.1])
                    rounded_box(ks_w - ks_leg_w * 2, ks_h + 2, ks_thick + 0.2, 2.5);

                // Carve the top-inner quadrant above the pivot axis (`Y >= pin_local_y`, `Z >= ks_thick/2`)
                // and replace it with a concentric cylinder + 58-degree planar stop bevel
                translate([-1, pin_local_y, ks_thick / 2])
                    cube([ks_w + 2, 10, ks_thick]);
            }

            // Add back the concentric barrel + 58-degree planar hard-stop wedge on the top of both legs
            for (lx = [0, ks_w - ks_leg_w]) {
                intersection() {
                    translate([lx, 0, 0])
                        asym_rounded_box(ks_leg_w, ks_h, ks_thick, ks_corner, ks_top_r);
                    union() {
                        // Concentric cylinder around pivot axis (R = ks_thick/2 = 1.5mm)
                        translate([lx, pin_local_y, ks_thick / 2])
                            rotate([0, 90, 0])
                                cylinder(r=ks_thick / 2, h=ks_leg_w);
                        // Knuckle block with exact 58-degree planar hard-stop face:
                        // At 58 deg rotation, this face becomes horizontal at Z = 3.65mm!
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

            // Left & Right Flat-Bottomed Root-Filleted Pivot Pins (at Y = pin_local_y = 40.4mm)
            translate([0.2, pin_local_y, ks_thick / 2])
                mirror([1, 0, 0])
                    d_pin(ks_pin_d, ks_pin_len + 0.2, root_fillet=1.0);

            translate([ks_w - 0.2, pin_local_y, ks_thick / 2])
                d_pin(ks_pin_d, ks_pin_len + 0.2, root_fillet=1.0);

            // Knuckle Detent Nubs for Full-Extension Click (at r = 2.30mm, angle = -12 deg relative to pivot):
            // Placed at Y = 42.65mm, Z = 1.02mm on the flat X = 0 and X = 64.0mm outer knuckle walls.
            // Protrudes 0.70mm (0.25mm interference past the 0.45mm wall clearance), flexing the 44mm
            // U-legs inward by 0.25mm over the solid crest before snapping into the 58-deg locking cups!
            translate([0.15, pin_local_y + 2.25, ks_thick / 2 - 0.48])
                sphere(r=0.85, $fn=28);
            translate([ks_w - 0.15, pin_local_y + 2.25, ks_thick / 2 - 0.48])
                sphere(r=0.85, $fn=28);

            // Closed-Position Retention Nubs near bottom of legs (Y = 9.0mm)
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
//    - 100% flat bottom (Z = 0) across all 3 sections for zero-overhang printing!
//    - 1.4mm thick retention flange slides in 2.4mm wide track (1.0mm stroke)
//    - 3.4mm pill head protrudes 1.60mm outside right wall at rest
//    - 1.15mm rear pusher nub clicks both 6x6x5.0mm and 6x6x4.3mm switches
// --------------------------------------------------------------------
module button_cap() {
    union() {
        // Retention flange (1.4 x 10.6 x 5.6 mm, sits on Z = 0)
        rounded_box(1.4, 10.6, 5.6, 0.6);

        // Exterior actuator pill head (flat on Z = 0, height 4.6mm -> 1.0mm top shoulder)
        translate([1.3, 1.4, 0])
            rounded_box(3.5, 7.8, 4.6, 1.4);

        // Rear pusher nub (flat on Z = 0, height 4.4mm -> contacts center of switch plunger at Z = 3.0mm)
        translate([-1.15, (10.6 - 3.6) / 2, 0])
            rounded_box(1.25, 3.6, 4.4, 0.5);
    }
}

// --------------------------------------------------------------------
// 7. Ghost Reference Models (Waveshare PCB, XIAO ESP32S3, LiPo, 6x6 Switch)
// --------------------------------------------------------------------
module ghost_electronics() {
    // Waveshare 4.2" Module (G) blue PCB (103.0 x 78.5 x 1.6 mm)
    color("#1e4d8c", 0.65)
        translate([pcb_x + 0.4, pcb_y + 0.4, back_h - 0.4])
            cube([103.0, 78.5, 1.6]);

    // Active e-ink glass panel
    color("#f4efe6", 0.9)
        translate([win_x, win_y, back_h + 1.2])
            cube([win_w, win_h, 1.2]);

    // Seeed Studio XIAO ESP32S3
    color("#222222", 0.8)
        translate([(frame_w - 17.8) / 2, 3.2, floor_t + 0.6])
            cube([17.8, 21.0, 4.2]);

    // 6x6x5mm Tactile Switch (mounted sideways in right-wall cradle)
    color("#444444", 0.85)
        translate([frame_w - 9.15, btn_y - 3.0, 3.2])
            cube([3.5, 6.0, 6.0]);

    // LiPo Battery Pouch
    color("#c0c0c0", 0.7)
        translate([(frame_w - 58) / 2, 31, floor_t + 0.2])
            rounded_box(58, 40, 5.0, 2.0);
}

// --------------------------------------------------------------------
// 8. Scene & Export Dispatcher
// --------------------------------------------------------------------
if (part == "assembled") {
    color("#2b2927") back_cover_geom();
    color("#d4a04a")
        translate([ks_x, ks_y, 0])
            kickstand();
    color("#d4a04a")
        translate([frame_w - 3.2, btn_y - 10.6 / 2, 3.25])
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
        translate([frame_w - 3.2, btn_y - 10.6 / 2, 3.25])
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
        translate([frame_w + 10, btn_y - 10.6 / 2, 3.25])
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
    // Ready to print flat on bed (Z = 0 is the rear exterior face, internal cavity faces UP)
    back_cover_geom();

} else if (part == "kickstand") {
    // Ready to print flat on bed
    kickstand();

} else if (part == "button") {
    // Ready to print flat on Z = 0 (all 3 sections share a flat base with zero overhangs)
    button_cap();
}
